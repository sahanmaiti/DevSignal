# tests/test_scorer.py
#
# Tests for scorer, classifier, and outreach generator.
# These tests do NOT make real API calls — they test
# the parsing and fallback logic only.
#
# Run with: python -m pytest tests/test_scorer.py -v
#
# PLACEMENT: tests/test_scorer.py

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from unittest.mock import patch, MagicMock
from ai.scorer import OpportunityScorer
from ai.ios_classifier import IOSClassifier


# ── Scorer JSON parsing ───────────────────────────────────────────────────

def make_scorer():
    """Create a scorer with a fake API key for testing."""
    with patch.dict(os.environ, {"GROQ_API_KEY": "test_key"}):
        with patch("ai.scorer.Groq"):
            return OpportunityScorer()

def make_classifier():
    with patch.dict(os.environ, {"GROQ_API_KEY": "test_key"}):
        with patch("ai.ios_classifier.Groq"):
            return IOSClassifier()


def test_scorer_parse_valid_json():
    scorer = make_scorer()
    raw = '''{
        "score": 74,
        "breakdown": {
            "remote_work": 20, "visa_sponsorship": 0,
            "swift_match": 15, "ios_product": 15,
            "experience_level": 10, "salary_mentioned": 10,
            "startup_potential": 4, "recency": 0
        },
        "summary": "Strong remote iOS role but no visa info"
    }'''
    result = scorer._parse_score_response(raw)
    assert result["score"] == 74
    assert result["breakdown"]["remote_work"] == 20
    assert "remote iOS" in result["summary"]


def test_scorer_parse_json_with_code_block():
    scorer = make_scorer()
    raw = '```json\n{"score": 85, "breakdown": {}, "summary": "Great role"}\n```'
    result = scorer._parse_score_response(raw)
    assert result["score"] == 85


def test_scorer_score_clamped_to_range():
    scorer = make_scorer()
    # Score of 150 should be clamped to 100
    raw = '{"score": 150, "breakdown": {}, "summary": "Too high"}'
    result = scorer._parse_score_response(raw)
    assert result["score"] == 100

    # Score of -5 should be clamped to 0
    raw = '{"score": -5, "breakdown": {}, "summary": "Too low"}'
    result = scorer._parse_score_response(raw)
    assert result["score"] == 0


def test_scorer_fallback_on_bad_json():
    scorer = make_scorer()
    result = scorer._fallback_score({
        "remote": "Yes",
        "visa_sponsorship": "Yes",
        "tech_stack": "swift, swiftui",
        "experience_req": "0-1 years",
    })
    assert result["score"] >= 50   # remote + visa + swiftui + experience
    assert result["breakdown"]["remote_work"] == 20
    assert result["breakdown"]["visa_sponsorship"] == 15


def test_scorer_fallback_scores_correctly():
    scorer = make_scorer()

    # Remote + SwiftUI should give at least 35 points
    job = {
        "remote": "Yes",
        "visa_sponsorship": "Unknown",
        "tech_stack": "swiftui, swift",
        "description_raw": "",
        "experience_req": "",
    }
    result = scorer._fallback_score(job)
    assert result["score"] >= 35


# ── Classifier heuristics ────────────────────────────────────────────────

def test_classifier_heuristic_swift_is_ios():
    classifier = make_classifier()
    result = classifier._heuristic_classify(
        "Mercury", "iOS Developer", "Building Swift app", "swift, swiftui"
    )
    assert result is not None
    assert result["builds_ios"] is True


def test_classifier_heuristic_react_native_not_ios():
    classifier = make_classifier()
    result = classifier._heuristic_classify(
        "Web Co", "Mobile Developer", "React Native app", "react native"
    )
    assert result is not None
    assert result["builds_ios"] is False


def test_classifier_heuristic_unsure_returns_none():
    classifier = make_classifier()
    # Ambiguous — should return None to trigger AI call
    result = classifier._heuristic_classify(
        "Mystery Co", "Mobile Developer", "Mobile app development", "mobile"
    )
    assert result is None


def test_classifier_parse_valid_response():
    classifier = make_classifier()
    raw = '{"builds_ios": true, "reason": "Company explicitly mentions Swift"}'
    result = classifier._parse_response(raw)
    assert result["builds_ios"] is True
    assert "Swift" in result["reason"]


def test_classifier_parse_false_response():
    classifier = make_classifier()
    raw = '{"builds_ios": false, "reason": "React Native only, no native iOS"}'
    result = classifier._parse_response(raw)
    assert result["builds_ios"] is False


def test_classifier_parse_invalid_json_falls_back():
    classifier = make_classifier()
    # Should not raise — should fall back gracefully
    result = classifier._parse_response("This is not JSON at all, but it says yes somewhere")
    assert "builds_ios" in result


if __name__ == "__main__":
    test_scorer_parse_valid_json()
    test_scorer_parse_json_with_code_block()
    test_scorer_score_clamped_to_range()
    test_scorer_fallback_on_bad_json()
    test_scorer_fallback_scores_correctly()
    test_classifier_heuristic_swift_is_ios()
    test_classifier_heuristic_react_native_not_ios()
    test_classifier_heuristic_unsure_returns_none()
    test_classifier_parse_valid_response()
    test_classifier_parse_false_response()
    test_classifier_parse_invalid_json_falls_back()
    print("All scorer tests passed.")