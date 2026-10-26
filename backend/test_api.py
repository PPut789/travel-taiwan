"""Contract tests: stub inference only, never fit or deserialize a model."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from main import ARTIFACT_FORMAT, RecommendationRequest, TrainedRecommender, create_app, verify_export


PROFILE = {"preferred_cities_en": [], "preferred_categories_en": ["Nature"],
           "preferred_types_en": ["Park"], "preferred_activities_en": ["Photography"],
           "age": 27, "gender": "Female", "limit": 10}


class StubRuntime:
    def bind_artifact(self, artifact):
        self.artifact = artifact

    def validate_profile(self, profile):
        return {"age_out_of_training_range": profile["age"] < 18}

    def recommend_attractions(self, profile, top_k):
        self.last_profile = profile
        candidates = self.artifact["ready_attractions"]
        if profile["preferred_cities_en"]:
            candidates = [a for a in candidates if a["_cached_info"]["city"] in profile["preferred_cities_en"]]
        results = [{"attraction": a, "knn_prob": .8, "has_real_rating": i == 0,
                    "avg_rating": 4.6 if i == 0 else 0, "review_count": 12 if i == 0 else 0}
                   for i, a in enumerate(candidates[:top_k])]
        return results, len(candidates), 0.99


def fixture():
    runtime = StubRuntime()
    artifact = {"artifact_format": ARTIFACT_FORMAT,
                "metadata": {"feature_dimensions": 60, "version": "V2.3-test"},
                "method_status": "experimental_not_promoted",
                "options": {"preferred_cities_en": ["Taipei City", "Tainan City", "Empty City"],
                            "preferred_categories_en": ["Nature"], "preferred_types_en": ["Park"],
                            "preferred_activities_en": ["Photography"]},
                "ready_attractions": [{"AttractionID": "B2", "_cached_info": {"city": "Taipei City"}},
                                      {"AttractionID": "A1", "_cached_info": {"city": "Tainan City"}}]}
    return TrainedRecommender(artifact, runtime, "a" * 64), runtime


class ApiTests(unittest.TestCase):
    def test_no_model_health_and_service_unavailable(self):
        with TestClient(create_app()) as client:
            self.assertEqual(client.get("/health").json()["status"], "model_not_configured")
            self.assertEqual(client.post("/recommend", json=PROFILE).status_code, 503)

    def test_exact_canonical_order_and_rating_separate_from_probability(self):
        adapter, runtime = fixture()
        with TestClient(create_app(recommender=adapter)) as client:
            response = client.post("/recommend", json=PROFILE)
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual([r["attractionId"] for r in body["results"]], ["B2", "A1"])
            self.assertEqual((body["total"], body["eligiblePool"]), (2, 2))
            self.assertEqual(body["results"][0]["avgRating"], 4.6)
            self.assertEqual(body["results"][0]["knnRuleProbability"], .8)
            self.assertIsNone(body["results"][1]["avgRating"])
            self.assertIsNone(body["results"][1]["reviewCount"])
            self.assertEqual(runtime.last_profile["age"], 27)
            self.assertNotIn("limit", runtime.last_profile)

    def test_selected_city_not_expanded_and_zero_is_a_valid_result(self):
        adapter, _ = fixture()
        with TestClient(create_app(recommender=adapter)) as client:
            one = client.post("/recommend", json={**PROFILE, "preferred_cities_en": ["Taipei City"]}).json()
            self.assertEqual([r["attractionId"] for r in one["results"]], ["B2"])
            empty = client.post("/recommend", json={**PROFILE, "preferred_cities_en": ["Empty City"]}).json()
            self.assertEqual((empty["results"], empty["eligiblePool"]), ([], 0))

    def test_strict_inputs_and_no_legacy_feature_fields(self):
        adapter, _ = fixture()
        invalid = [{"age": True}, {"age": "27"}, {"age": 0}, {"age": 1.5},
                   {"gender": "Unknown"}, {"limit": 11}, {"limit": True},
                   {"preferred_categories_en": []}, {"preferred_types_en": [""]},
                   {"regions": ["North"]}, {"keywords": ["photo"]}, {"exclude_source_rows": [1]}]
        with TestClient(create_app(recommender=adapter)) as client:
            for fields in invalid:
                with self.subTest(fields=fields):
                    self.assertEqual(client.post("/recommend", json={**PROFILE, **fields}).status_code, 422)
            response = client.post("/recommend", json={**PROFILE, "preferred_categories_en": ["Invented"]})
            self.assertEqual(response.status_code, 400)
            young = client.post("/recommend", json={**PROFILE, "age": 1}).json()
            self.assertEqual(young["warnings"], ["age_out_of_training_range"])

    def test_bad_runtime_output_is_rejected(self):
        adapter, runtime = fixture()
        request = RecommendationRequest(**PROFILE)
        duplicate = {"attraction": adapter.artifact["ready_attractions"][0], "knn_prob": .8,
                     "has_real_rating": False, "avg_rating": 0, "review_count": 0}
        with patch.object(runtime, "recommend_attractions", return_value=([duplicate, duplicate], 2, .9)):
            with self.assertRaisesRegex(RuntimeError, "duplicate"):
                adapter.recommend(request)
        with patch.object(runtime, "recommend_attractions", return_value=([duplicate], 0, .9)):
            with self.assertRaisesRegex(RuntimeError, "count"):
                adapter.recommend(request)


class VerificationTests(unittest.TestCase):
    def test_manifest_and_environment_checked_without_deserializing(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            model, runtime, receipt = base / "model.pkl", base / "v23_runtime.py", base / "run_receipt.json"
            model.write_bytes(b"deliberately-not-a-pickle")
            runtime.write_text("raise RuntimeError('must not execute')", encoding="utf-8")
            digest = hashlib.sha256(model.read_bytes()).hexdigest()
            versions = {"numpy": "2.1.3", "pandas": "2.2.3", "scikit_learn": "1.6.1",
                        "scipy": "test", "joblib": "test", "threadpoolctl": "test"}
            data = {"execution_environment": "Google Colab", "model_sha256": digest,
                    "code_sha256": {runtime.name: hashlib.sha256(runtime.read_bytes()).hexdigest()},
                    "versions": {"python": "3.13.16", **versions}}
            receipt.write_text(json.dumps(data), encoding="utf-8")
            with patch("pickle.load", side_effect=AssertionError("No pickle loading in tests")) as loader:
                verify_export(model, runtime, receipt, digest, versions=versions, python_version="3.13.13")
                with self.assertRaisesRegex(ValueError, "major/minor"):
                    verify_export(model, runtime, receipt, digest, versions=versions, python_version="3.12.0")
                with self.assertRaisesRegex(ValueError, "numpy version"):
                    verify_export(model, runtime, receipt, digest, versions={**versions, "numpy": "2.0"}, python_version="3.13.13")
                runtime.write_text("changed", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Runtime SHA"):
                    verify_export(model, runtime, receipt, digest, versions=versions, python_version="3.13.13")
                loader.assert_not_called()

    def test_explicit_sha_required_and_no_automatic_loading_in_tests(self):
        with self.assertRaisesRegex(ValueError, "TAIWAN_MODEL_SHA256"):
            verify_export(Path("unused"), Path("unused"), Path("unused"), "")
        with patch.dict("os.environ", {"TAIWAN_MODEL_PATH": "must-not-load.pkl"}):
            with patch.object(TrainedRecommender, "from_export", side_effect=AssertionError("Must not load")):
                with TestClient(create_app()) as client:
                    self.assertEqual(client.get("/health").json()["status"], "model_not_configured")


if __name__ == "__main__":
    unittest.main()
