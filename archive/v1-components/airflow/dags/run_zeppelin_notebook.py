from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import requests
import time


ZEPPELIN_HOST = "http://zeppelin:8080"
NOTEBOOK_ID = "2MF3ZWZZB"


def run_zeppelin_notebook():
    # Trigger notebook run
    trigger_url = f"{ZEPPELIN_HOST}/api/notebook/job/{NOTEBOOK_ID}"
    r = requests.post(trigger_url)

    if r.status_code != 200:
        raise Exception(f"Failed to trigger notebook: {r.text}")

    print("Notebook triggered successfully")

    # Poll status
    status_url = f"{ZEPPELIN_HOST}/api/notebook/job/{NOTEBOOK_ID}"

    while True:
        status_resp = requests.get(status_url).json()
        jobs = status_resp.get("body", {}).get("paragraphs", [])

        if not jobs:
            print("No running jobs found")
            break

        all_finished = True
        for job in jobs:
            if job["status"] in ["RUNNING", "PENDING"]:
                all_finished = False
                print(f"Paragraph {job['id']} still running")

            if job["status"] == "ERROR":
                raise Exception("Zeppelin job failed")

        if all_finished:
            print("Zeppelin notebook completed successfully")
            break

        time.sleep(10)


with DAG(
    dag_id="run_zeppelin_notebook",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,  # manual trigger
    catchup=False,
    tags=["zeppelin", "spark"],
) as dag:

    run_notebook = PythonOperator(
        task_id="run_zeppelin_notebook",
        python_callable=run_zeppelin_notebook,
    )
