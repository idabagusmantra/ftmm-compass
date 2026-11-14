"""Kontrak resource transkrip mahasiswa dan rekonsiliasi Dashboard."""

from fastapi.testclient import TestClient

RECORDS = "/api/v1/me/course-records"
DASHBOARD = "/api/v1/dashboard/me"
PLANS = "/api/v1/degree-plans"


def _records(client: TestClient, headers: dict) -> list[dict]:
    response = client.get(RECORDS, headers=headers)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["meta"]["total"] == len(body["data"])
    return body["data"]


def _mark(client: TestClient, headers: dict, code: str, grade: str):
    return client.post(
        RECORDS, json={"course_code": code, "final_grade": grade}, headers=headers
    )


def _activate_plan(client: TestClient, headers: dict, codes: list[str]):
    created = client.post(
        PLANS,
        json={
            "name": "Rencana Rekonsiliasi",
            "items": [
                {"course_code": code, "planned_semester": 5} for code in codes
            ],
        },
        headers=headers,
    )
    assert created.status_code == 201, created.text
    plan = created.json()
    activated = client.patch(
        f"{PLANS}/{plan['id']}", json={"status": "active"}, headers=headers
    )
    assert activated.status_code == 200, activated.text
    return plan


def test_requires_authentication(client):
    assert client.get(RECORDS).status_code == 401


def test_rejects_non_student(client, lecturer_headers):
    assert client.get(RECORDS, headers=lecturer_headers).status_code == 403


def test_lists_seeded_transcript(client, student_headers):
    records = _records(client, student_headers)
    passed = [item for item in records if item["record_status"] == "passed"]
    assert len(passed) >= 16
    sample = passed[0]
    assert sample["final_grade"] in {"A", "AB", "B", "BC", "C", "D"}
    assert 1 <= sample["semester"] <= 8
    assert sample["period"]["label"].startswith(("Ganjil", "Genap"))
    assert sample["credits"] > 0


def test_mark_new_course_passed(client, student_headers):
    before = _records(client, student_headers)
    response = _mark(client, student_headers, "TSD301", "A")
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["record_status"] == "passed"
    assert body["final_grade"] == "A"
    assert response.headers["Location"] == f"{RECORDS}/{body['id']}"

    after = _records(client, student_headers)
    assert len(after) == len(before) + 1
    assert body["id"] in [item["id"] for item in after]


def test_mark_taking_course_updates_existing_attempt(client, student_headers):
    taking = [
        item
        for item in _records(client, student_headers)
        if item["record_status"] == "taking"
    ]
    assert taking, "seed harus menyediakan minimal satu record 'taking'"
    target = taking[0]

    response = _mark(client, student_headers, target["code"], "AB")
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["id"] == target["id"]
    assert body["record_status"] == "passed"
    assert body["final_grade"] == "AB"

    statuses = {
        item["id"]: item["record_status"]
        for item in _records(client, student_headers)
    }
    assert statuses[target["id"]] == "passed"


def test_duplicate_completion_rejected(client, student_headers):
    passed = [
        item
        for item in _records(client, student_headers)
        if item["record_status"] == "passed"
    ][0]
    response = _mark(client, student_headers, passed["code"], "A")
    assert response.status_code == 409, response.text
    assert response.json()["error"]["code"] == "already_completed"


def test_unknown_course_rejected(client, student_headers):
    response = _mark(client, student_headers, "QQQ000", "A")
    assert response.status_code == 422, response.text
    assert response.json()["error"]["code"] == "unknown_course"


def test_unknown_and_failing_grades_rejected(client, student_headers):
    unknown = _mark(client, student_headers, "TSD302", "Z")
    assert unknown.status_code == 422, unknown.text
    assert unknown.json()["error"]["code"] == "unknown_grade"

    failing = _mark(client, student_headers, "TSD302", "E")
    assert failing.status_code == 422, failing.text
    assert failing.json()["error"]["code"] == "non_passing_grade"


def test_delete_record(client, student_headers):
    created = _mark(client, student_headers, "TSD302", "B").json()
    response = client.delete(f"{RECORDS}/{created['id']}", headers=student_headers)
    assert response.status_code == 204, response.text
    assert created["id"] not in [
        item["id"] for item in _records(client, student_headers)
    ]
    again = client.delete(f"{RECORDS}/{created['id']}", headers=student_headers)
    assert again.status_code == 404, again.text


def test_dashboard_planned_comes_from_active_plan(client, student_headers):
    _activate_plan(client, student_headers, ["TSD301", "TSD302"])
    stats = client.get(DASHBOARD, headers=student_headers).json()["stats"]
    assert stats["courses_planned"] == 2
    assert stats["sks_planned"] == 6

    assert _mark(client, student_headers, "TSD301", "A").status_code == 201
    stats = client.get(DASHBOARD, headers=student_headers).json()["stats"]
    assert stats["courses_planned"] == 1
    assert stats["sks_planned"] == 3
