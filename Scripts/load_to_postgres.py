import os
import sys
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

def main():
    # 1. Load environment variables from .env
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
    else:
        load_dotenv()
        
    db_host = os.getenv('DB_HOST')
    db_port = os.getenv('DB_PORT')
    db_name = os.getenv('DB_NAME')
    db_user = os.getenv('DB_USER')
    db_pass = os.getenv('DB_PASSWORD')
    
    # Check if user has updated the credentials
    if not all([db_host, db_port, db_name, db_user, db_pass]) or db_pass == 'your_password':
        print("[ERROR] Database credentials are not fully configured in the .env file.")
        print("Please open the .env file and populate it with your actual PostgreSQL connection details.")
        print(f"Current configuration loaded from: {env_path}")
        print(f"DB_HOST: {db_host}")
        print(f"DB_PORT: {db_port}")
        print(f"DB_NAME: {db_name}")
        print(f"DB_USER: {db_user}")
        sys.exit(1)

    print("Connecting to PostgreSQL database...")
    try:
        # Create SQLAlchemy engine
        connection_url = f"postgresql+psycopg2://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
        engine = create_engine(connection_url)
        
        # Test connection
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("Connection successful!")
    except Exception as e:
        print(f"[ERROR] Failed to connect to the database: {e}")
        print("Make sure PostgreSQL is running and the credentials in the .env file are correct.")
        sys.exit(1)

    # 2. Read the cleaned dataset
    csv_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
        'Dataset', 'clean', 'bmw_cleaned.csv'
    )
    
    if not os.path.exists(csv_path):
        print(f"[ERROR] Cleaned dataset not found at: {csv_path}")
        sys.exit(1)
        
    print(f"Reading cleaned dataset from {csv_path}...")
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} rows.")

    # 3. Data prep & type conversion
    df['sale_date'] = pd.to_datetime(df['sale_date'])
    df['date_key'] = df['sale_date'].dt.strftime('%Y%m%d').astype(int)
    
    # Cast nullable numeric columns properly
    df['loan_term_months'] = pd.to_numeric(df['loan_term_months'], errors='coerce').astype('Int64')
    df['customer_satisfaction_score'] = pd.to_numeric(df['customer_satisfaction_score'], errors='coerce').astype(float)
    df['is_repeat_customer'] = df['is_repeat_customer'].astype(bool)
    df['trade_in'] = df['trade_in'].astype(bool)

    # 4. Extract unique dimension records
    print("Normalizing data into Star Schema...")
    
    # DimDate
    dim_date = df[['date_key', 'sale_date', 'sale_year', 'sale_month', 'sale_quarter']].drop_duplicates().reset_index(drop=True)
    dim_date = dim_date.rename(columns={
        'sale_year': 'year',
        'sale_month': 'month',
        'sale_quarter': 'quarter'
    })
    
    # DimModel
    dim_model = df[['model', 'variant', 'segment', 'body_style', 'fuel_type', 'transmission']].drop_duplicates().reset_index(drop=True)
    dim_model.insert(0, 'model_key', range(1, len(dim_model) + 1))
    
    # DimRegion
    dim_region = df[['region', 'country']].drop_duplicates().reset_index(drop=True)
    dim_region.insert(0, 'region_key', range(1, len(dim_region) + 1))
    
    # DimCustomer
    dim_customer = df[['customer_type', 'financing_type', 'sales_channel', 'warranty_package']].drop_duplicates().reset_index(drop=True)
    dim_customer.insert(0, 'customer_key', range(1, len(dim_customer) + 1))

    # 5. Map foreign keys to the main fact dataframe
    df = df.merge(dim_model, on=['model', 'variant', 'segment', 'body_style', 'fuel_type', 'transmission'], how='left')
    df = df.merge(dim_region, on=['region', 'country'], how='left')
    df = df.merge(dim_customer, on=['customer_type', 'financing_type', 'sales_channel', 'warranty_package'], how='left')

    # FactSales
    fact_sales = df[[
        'transaction_id',
        'date_key',
        'model_key',
        'region_key',
        'customer_key',
        'msrp_usd',
        'final_sale_price_usd',
        'discount_percent',
        'discount_amount_usd',
        'options_cost_usd',
        'discount_bucket',
        'loan_term_months',
        'delivery_days',
        'delivery_category',
        'customer_satisfaction_score',
        'is_repeat_customer',
        'trade_in'
    ]].copy()

    # 6. Execute DDL to drop and recreate tables
    ddl_statements = [
        "DROP TABLE IF EXISTS FactSales CASCADE;",
        "DROP TABLE IF EXISTS DimCustomer CASCADE;",
        "DROP TABLE IF EXISTS DimRegion CASCADE;",
        "DROP TABLE IF EXISTS DimModel CASCADE;",
        "DROP TABLE IF EXISTS DimDate CASCADE;",
        """
        CREATE TABLE DimDate (
            date_key INT PRIMARY KEY,
            sale_date DATE NOT NULL,
            year INT NOT NULL,
            month INT NOT NULL,
            quarter VARCHAR(10) NOT NULL
        );
        """,
        """
        CREATE TABLE DimModel (
            model_key INT PRIMARY KEY,
            model VARCHAR(100) NOT NULL,
            variant VARCHAR(100) NOT NULL,
            segment VARCHAR(100),
            body_style VARCHAR(100),
            fuel_type VARCHAR(100),
            transmission VARCHAR(100)
        );
        """,
        """
        CREATE TABLE DimRegion (
            region_key INT PRIMARY KEY,
            region VARCHAR(100) NOT NULL,
            country VARCHAR(100) NOT NULL
        );
        """,
        """
        CREATE TABLE DimCustomer (
            customer_key INT PRIMARY KEY,
            customer_type VARCHAR(100),
            financing_type VARCHAR(100),
            sales_channel VARCHAR(100),
            warranty_package VARCHAR(100)
        );
        """,
        """
        CREATE TABLE FactSales (
            transaction_id VARCHAR(50) PRIMARY KEY,
            date_key INT REFERENCES DimDate(date_key),
            model_key INT REFERENCES DimModel(model_key),
            region_key INT REFERENCES DimRegion(region_key),
            customer_key INT REFERENCES DimCustomer(customer_key),
            msrp_usd NUMERIC(12, 2) NOT NULL,
            final_sale_price_usd NUMERIC(12, 2) NOT NULL,
            discount_percent NUMERIC(5, 2) NOT NULL,
            discount_amount_usd NUMERIC(12, 2) NOT NULL,
            options_cost_usd NUMERIC(12, 2) NOT NULL,
            discount_bucket VARCHAR(20) NOT NULL,
            loan_term_months INT, -- can be NULL
            delivery_days INT NOT NULL,
            delivery_category VARCHAR(20) NOT NULL,
            customer_satisfaction_score NUMERIC(3, 1), -- can be NULL
            is_repeat_customer BOOLEAN NOT NULL,
            trade_in BOOLEAN NOT NULL
        );
        """
    ]

    print("Recreating database schema (Drop & Create)...")
    try:
        with engine.begin() as conn:
            for statement in ddl_statements:
                conn.execute(text(statement))
        print("Schema successfully recreated.")
    except Exception as e:
        print(f"[ERROR] Failed to execute DDL statements: {e}")
        sys.exit(1)

    # 7. Write DataFrames to PostgreSQL
    print("Loading data into PostgreSQL tables...")
    try:
        # Write dimensions first
        dim_date.to_sql('dimdate', engine, if_exists='append', index=False)
        print(f"Loaded {len(dim_date)} rows into DimDate.")
        
        dim_model.to_sql('dimmodel', engine, if_exists='append', index=False)
        print(f"Loaded {len(dim_model)} rows into DimModel.")
        
        dim_region.to_sql('dimregion', engine, if_exists='append', index=False)
        print(f"Loaded {len(dim_region)} rows into DimRegion.")
        
        dim_customer.to_sql('dimcustomer', engine, if_exists='append', index=False)
        print(f"Loaded {len(dim_customer)} rows into DimCustomer.")
        
        # Write fact table
        fact_sales.to_sql('factsales', engine, if_exists='append', index=False)
        print(f"Loaded {len(fact_sales)} rows into FactSales.")
        
        print("\n[SUCCESS] All data has been successfully loaded into PostgreSQL!")
    except Exception as e:
        print(f"[ERROR] Failed to load data to tables: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
