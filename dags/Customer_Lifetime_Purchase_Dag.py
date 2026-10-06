from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCheckOperator,
    BigQueryInsertJobOperator,
)



PROJECT_ID = "cobalt-mantis-464811-j9"
DATASET = "Tatvic_Technical_Assesment"

ORDERS_TABLE = f"{PROJECT_ID}.{DATASET}.orders"
DAILY_AGG_TABLE = f"{PROJECT_ID}.{DATASET}.customer_daily_orders"
LIFETIME_TABLE = f"{PROJECT_ID}.{DATASET}.customer_lifetime_purchase"


default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    dag_id="Customer_Lifetime_Purchase_Update",
    start_date=datetime(2026, 10, 06),
    schedule="0 2 * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
) as dag:

    check_orders_available = BigQueryCheckOperator(
        task_id="check_orders_available",

        sql=f"""
        SELECT COUNT(*) > 0
        FROM `{ORDERS_TABLE}`
        WHERE order_date = DATE('{{{{ ds }}}}')
        """,

        use_legacy_sql=False,

        gcp_conn_id="bigquery_default",
    )



    validate_orders = BigQueryCheckOperator(
        task_id="validate_orders",

        sql=f"""
        SELECT COUNT(*) = 0
        FROM `{ORDERS_TABLE}`
        WHERE order_date = DATE('{{{{ ds }}}}')
          AND (
              order_id IS NULL
              OR user_id IS NULL
              OR revenue IS NULL
          )
        """,

        use_legacy_sql=False,

        gcp_conn_id="bigquery_default",
    )


    create_daily_customer_aggregate = BigQueryInsertJobOperator(
        task_id="create_daily_customer_aggregate",

        configuration={
            "query": {
                "query": f"""
                MERGE `{DAILY_AGG_TABLE}` AS target

                USING (

                    SELECT
                        order_date,
                        user_id,

                        COUNT(DISTINCT order_id) AS order_count,

                        SUM(revenue) AS revenue

                    FROM `{ORDERS_TABLE}`

                    WHERE order_date = DATE('{{{{ ds }}}}')

                    GROUP BY
                        order_date,
                        user_id

                ) AS source

                ON target.order_date = source.order_date
                AND target.user_id = source.user_id

                WHEN MATCHED THEN

                    UPDATE SET
                        order_count = source.order_count,
                        revenue = source.revenue

                WHEN NOT MATCHED THEN

                    INSERT (
                        order_date,
                        user_id,
                        order_count,
                        revenue
                    )

                    VALUES (
                        source.order_date,
                        source.user_id,
                        source.order_count,
                        source.revenue
                    )
                """,

                "useLegacySql": False,
            }
        },

        gcp_conn_id="bigquery_default",
    )


    update_lifetime_table = BigQueryInsertJobOperator(
        task_id="update_lifetime_table",

        configuration={
            "query": {
                "query": f"""
                MERGE `{LIFETIME_TABLE}` AS target

                USING (

                    SELECT
                        user_id,

                        SUM(order_count) AS lifetime_orders,

                        SUM(revenue) AS lifetime_revenue

                    FROM `{DAILY_AGG_TABLE}`

                    WHERE user_id IN (

                        SELECT DISTINCT user_id

                        FROM `{DAILY_AGG_TABLE}`

                        WHERE order_date = DATE('{{{{ ds }}}}')

                    )

                    GROUP BY user_id

                ) AS source

                ON target.user_id = source.user_id

                WHEN MATCHED THEN

                    UPDATE SET
                        lifetime_orders = source.lifetime_orders,
                        lifetime_revenue = source.lifetime_revenue

                WHEN NOT MATCHED THEN

                    INSERT (
                        user_id,
                        lifetime_orders,
                        lifetime_revenue
                    )

                    VALUES (
                        source.user_id,
                        source.lifetime_orders,
                        source.lifetime_revenue
                    )
                """,

                "useLegacySql": False,
            }
        },

        gcp_conn_id="bigquery_default",
    )


    validate_lifetime_table = BigQueryCheckOperator(
        task_id="validate_lifetime_table",

        sql=f"""
        SELECT COUNT(*) = 0
        FROM `{LIFETIME_TABLE}`
        WHERE user_id IS NULL
           OR lifetime_orders < 0
           OR lifetime_revenue < 0
        """,

        use_legacy_sql=False,

        gcp_conn_id="bigquery_default",
        
    )


check_orders_available >> validate_orders >> create_daily_customer_aggregate >> update_lifetime_table >> validate_lifetime_table
