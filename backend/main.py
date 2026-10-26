"""Inference adapter for the separately trained Taiwan V2.3 Colab export."""
from __future__ import annotations

import hashlib
import importlib.metadata
import importlib.util
import json
import math
import os
import platform
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, Literal

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, StrictStr, field_validator

MODEL_VERSION = "KNN_InterestV2_3_Demographics_Ratings1352_2026-10-26"
ARTIFACT_FORMAT = "taiwan-v23-pairwise-knn-bundle-1"
INTEREST_FIELDS = (
    "preferred_cities_en", "preferred_categories_en",
    "preferred_types_en", "preferred_activities_en",
)


class RecommendationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    preferred_cities_en: list[StrictStr] = Field(default_factory=list)
    preferred_categories_en: list[StrictStr] = Field(min_length=1)
    preferred_types_en: list[StrictStr] = Field(min_length=1)
    preferred_activities_en: list[StrictStr] = Field(min_length=1)
    age: int = Field(gt=0, strict=True)
    gender: Literal["Female", "Male", "Other"]
    limit: int = Field(default=10, ge=1, le=10, strict=True)

    @field_validator(*INTEREST_FIELDS, mode="before")
    @classmethod
    def clean_options(cls, values: Any) -> Any:
        if not isinstance(values, list) or any(not isinstance(v, str) for v in values):
            return values
        cleaned = list(dict.fromkeys(v.strip() for v in values))
        if any(not v for v in cleaned):
            raise ValueError("Interest options cannot be blank.")
        return cleaned


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_export(
    model_path: Path, runtime_path: Path, receipt_path: Path, expected_sha256: str,
    *, versions: dict[str, str] | None = None, python_version: str | None = None,
) -> dict[str, Any]:
    """Check bytes and environment before importing runtime code or unpickling."""
    if len(expected_sha256) != 64 or any(c not in "0123456789abcdef" for c in expected_sha256):
        raise ValueError("Set TAIWAN_MODEL_SHA256 to the independently verified Colab model SHA-256.")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("execution_environment") != "Google Colab":
        raise ValueError("The export must include a Google Colab run receipt.")
    if receipt.get("model_sha256") != expected_sha256 or file_sha256(model_path) != expected_sha256:
        raise ValueError("Model SHA-256 does not match the trusted export.")
    runtime_hash = receipt.get("code_sha256", {}).get(runtime_path.name)
    if not runtime_hash or file_sha256(runtime_path) != runtime_hash:
        raise ValueError("Runtime SHA-256 does not match the Colab receipt.")
    recorded = receipt.get("versions", {})
    actual_python = python_version or platform.python_version()
    if actual_python.split(".")[:2] != str(recorded.get("python", "")).split(".")[:2]:
        raise ValueError("Python major/minor must match the Colab export.")
    names = {"numpy": "numpy", "pandas": "pandas", "scikit_learn": "scikit-learn",
             "scipy": "scipy", "joblib": "joblib", "threadpoolctl": "threadpoolctl"}
    for key, package in names.items():
        expected = recorded.get(key) or receipt.get("dependency_versions", {}).get(package)
        if not expected:
            raise ValueError(f"Colab receipt is missing {package} version.")
        actual = versions.get(key) if versions is not None else importlib.metadata.version(package)
        if actual != expected:
            raise ValueError(f"{package} version must match Colab ({expected}).")
    return receipt


class TrainedRecommender:
    def __init__(self, artifact: dict[str, Any], runtime: Any, model_sha256: str):
        # Tests can supply a stub runtime; constructing this class never loads pickle.
        if artifact.get("artifact_format") != ARTIFACT_FORMAT:
            raise ValueError("Unsupported Taiwan artifact format.")
        self.artifact = artifact
        self.runtime = runtime
        self.model_sha256 = model_sha256
        self.options = artifact["options"]
        for key in INTEREST_FIELDS:
            values = self.options.get(key)
            if not isinstance(values, list) or not values or any(not isinstance(v, str) for v in values):
                raise ValueError(f"Invalid artifact options: {key}.")
        catalog = artifact["ready_attractions"]
        ids = [a.get("AttractionID") for a in catalog]
        if any(not isinstance(i, str) or not i for i in ids) or len(set(ids)) != len(ids):
            raise ValueError("Artifact must contain unique canonical AttractionIDs.")
        self.catalog_ids = set(ids)
        self.metadata = artifact.get("metadata", {})
        if self.metadata.get("feature_dimensions") != 60:
            raise ValueError("V2.3 requires the 60-feature demographic artifact.")
        self.version = self.metadata.get("version", MODEL_VERSION)
        runtime.bind_artifact(artifact)

    @classmethod
    def from_export(cls, model_path: Path, expected_sha256: str) -> "TrainedRecommender":
        runtime_path = model_path.parent / "v23_runtime.py"
        receipt_path = model_path.parent / "run_receipt.json"
        verify_export(model_path, runtime_path, receipt_path, expected_sha256)
        spec = importlib.util.spec_from_file_location("taiwan_verified_v23_runtime", runtime_path)
        if spec is None or spec.loader is None:
            raise ValueError("Cannot import verified V2.3 runtime.")
        runtime = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runtime)
        # Only explicitly configured server startup reaches this, after all checks.
        import pickle
        with model_path.open("rb") as source:
            artifact = pickle.load(source)
        return cls(artifact, runtime, expected_sha256)

    def recommend(self, request: RecommendationRequest) -> dict[str, Any]:
        profile = request.model_dump(exclude={"limit"})
        for key in INTEREST_FIELDS:
            unknown = set(profile[key]) - set(self.options[key])
            if unknown:
                raise ValueError(f"Unknown options for {key}: {', '.join(sorted(unknown))}.")
        age_info = self.runtime.validate_profile(profile)
        selected, eligible_pool, _quality_proxy = self.runtime.recommend_attractions(profile, top_k=request.limit)
        if not isinstance(eligible_pool, int) or eligible_pool < len(selected) or len(selected) > request.limit:
            raise RuntimeError("Runtime returned an invalid result count.")
        results = []
        seen: set[str] = set()
        for rank, candidate in enumerate(selected, 1):
            attraction = candidate["attraction"]
            canonical_id = attraction["AttractionID"]
            if canonical_id not in self.catalog_ids or canonical_id in seen:
                raise RuntimeError("Runtime returned an invalid or duplicate AttractionID.")
            seen.add(canonical_id)
            if profile["preferred_cities_en"] and attraction["_cached_info"]["city"] not in profile["preferred_cities_en"]:
                raise RuntimeError("Runtime returned an attraction outside the selected cities.")
            has_rating = bool(candidate["has_real_rating"])
            rating = float(candidate["avg_rating"]) if has_rating else None
            review_count = int(candidate["review_count"]) if has_rating else None
            if has_rating and (not math.isfinite(rating) or not 0 < rating <= 5 or review_count < 0):
                raise RuntimeError("Runtime returned invalid public rating metadata.")
            probability = float(candidate["knn_prob"])
            if not math.isfinite(probability) or not 0 <= probability <= 1:
                raise RuntimeError("Runtime returned invalid rule probability.")
            results.append({"attractionId": canonical_id, "rank": rank,
                            "knnRuleProbability": probability, "hasRealRating": has_rating,
                            "avgRating": rating, "reviewCount": review_count})
        return {"modelVersion": self.version, "methodStatus": self.artifact.get("method_status"),
                "total": len(results), "eligiblePool": eligible_pool, "limit": request.limit,
                "warnings": ["age_out_of_training_range"] if age_info.get("age_out_of_training_range") else [],
                "results": results}

    def status(self) -> dict[str, Any]:
        return {"ok": True, "service": "Tour Travel Recommendation API",
                "modelVersion": self.version, "modelSha256": self.model_sha256,
                "featureDimensions": self.metadata["feature_dimensions"],
                "readyAttractions": len(self.catalog_ids),
                "methodStatus": self.artifact.get("method_status")}


def create_app(*, recommender: Any = None, load_configured_model: bool = False) -> FastAPI:
    @asynccontextmanager
    async def lifespan(application: FastAPI):
        if load_configured_model and application.state.recommender is None:
            configured_path = os.environ.get("TAIWAN_MODEL_PATH", "").strip()
            if configured_path:
                application.state.recommender = TrainedRecommender.from_export(
                    Path(configured_path).resolve(), os.environ.get("TAIWAN_MODEL_SHA256", "").strip().lower())
        yield

    application = FastAPI(title="Tour Travel Recommendation API", version="0.3.0", lifespan=lifespan)
    application.state.recommender = recommender
    application.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=False,
                               allow_methods=["GET", "POST"], allow_headers=["Content-Type"])

    @application.get("/")
    @application.get("/health")
    def health() -> dict[str, Any]:
        active = application.state.recommender
        if active is None:
            return {"ok": False, "service": "Tour Travel Recommendation API", "status": "model_not_configured"}
        return active.status()

    @application.post("/recommend")
    def recommend(request: RecommendationRequest) -> dict[str, Any]:
        active = application.state.recommender
        if active is None:
            raise HTTPException(status_code=503, detail="Taiwan model is not configured.")
        try:
            return active.recommend(request)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    return application


app = create_app(load_configured_model=True)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=os.environ.get("TAIWAN_API_HOST", "127.0.0.1"),
                port=int(os.environ.get("TAIWAN_API_PORT", "8010")), reload=False)
