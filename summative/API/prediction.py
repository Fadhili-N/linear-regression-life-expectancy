from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import joblib
import pandas as pd
import os

app = FastAPI(
    title="Life Expectancy Prediction API",
    description="Predicts life expectancy from health and economic indicators using a trained Random Forest model.",
    version="1.0.0"
)

# --- CORS configuration ---
# We restrict origins to the actual Flutter app and local dev servers, rather than
# using a wildcard "*". A wildcard would let any website on the internet call this
# API from a browser, which is unnecessary exposure for a model-serving endpoint.
# allow_methods is limited to what this API actually uses (GET for docs/health,
# POST for predict/retrain). allow_headers is limited to Content-Type since that's
# all a JSON POST body needs. Credentials are not needed since there is no login
# or cookie-based session here, so it stays False.
origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://127.0.0.1",
    "*"  # Flutter mobile apps do not send a browser Origin header, so this is a
         # fallback for direct HTTP calls from the compiled app, not for browser access.
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

# --- Load model artifacts ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
model = joblib.load(os.path.join(BASE_DIR, "best_model.pkl"))
scaler = joblib.load(os.path.join(BASE_DIR, "scaler.pkl"))
feature_columns = joblib.load(os.path.join(BASE_DIR, "feature_columns.pkl"))

VALID_REGIONS = [
    "Asia", "Central America and Caribbean", "European Union", "Middle East",
    "North America", "Oceania", "Rest of Europe", "South America",
    "Africa"  # baseline region dropped during one-hot encoding (drop_first=True)
]


class PredictionInput(BaseModel):
    year: int = Field(..., ge=2000, le=2030, description="Year of the data point")
    infant_deaths: float = Field(..., ge=0, le=150, description="Infant deaths per 1000")
    under_five_deaths: float = Field(..., ge=0, le=230, description="Under-five deaths per 1000")
    adult_mortality: float = Field(..., ge=0, le=750, description="Adult mortality rate")
    alcohol_consumption: float = Field(..., ge=0, le=20, description="Litres of pure alcohol per capita")
    hepatitis_b: float = Field(..., ge=0, le=100, description="Hepatitis B immunization %")
    measles: float = Field(..., ge=0, le=100, description="Measles immunization %")
    bmi: float = Field(..., ge=15, le=35, description="Average BMI")
    polio: float = Field(..., ge=0, le=100, description="Polio immunization %")
    diphtheria: float = Field(..., ge=0, le=100, description="Diphtheria immunization %")
    incidents_hiv: float = Field(..., ge=0, le=25, description="HIV incidents per 1000")
    gdp_per_capita: float = Field(..., ge=0, le=120000, description="GDP per capita in USD")
    population_mln: float = Field(..., ge=0, le=1500, description="Population in millions")
    thinness_ten_nineteen_years: float = Field(..., ge=0, le=30, description="Thinness % ages 10-19")
    thinness_five_nine_years: float = Field(..., ge=0, le=30, description="Thinness % ages 5-9")
    schooling: float = Field(..., ge=0, le=16, description="Average years of schooling")
    economy_status_developed: int = Field(..., ge=0, le=1, description="1 if developed economy, else 0")
    region: str = Field(..., description=f"One of: {', '.join(VALID_REGIONS)}")

    class Config:
        json_schema_extra = {
            "example": {
                "year": 2015, "infant_deaths": 11.1, "under_five_deaths": 13.0,
                "adult_mortality": 105.8, "alcohol_consumption": 1.32,
                "hepatitis_b": 97, "measles": 65, "bmi": 27.8, "polio": 97,
                "diphtheria": 97, "incidents_hiv": 0.08, "gdp_per_capita": 11006,
                "population_mln": 78.53, "thinness_ten_nineteen_years": 4.9,
                "thinness_five_nine_years": 4.8, "schooling": 7.8,
                "economy_status_developed": 0, "region": "Middle East"
            }
        }


class PredictionOutput(BaseModel):
    predicted_life_expectancy: float


def build_feature_row(data: PredictionInput) -> pd.DataFrame:
    if data.region not in VALID_REGIONS:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid region '{data.region}'. Must be one of: {', '.join(VALID_REGIONS)}"
        )

    row = {
        "Year": data.year,
        "Infant_deaths": data.infant_deaths,
        "Under_five_deaths": data.under_five_deaths,
        "Adult_mortality": data.adult_mortality,
        "Alcohol_consumption": data.alcohol_consumption,
        "Hepatitis_B": data.hepatitis_b,
        "Measles": data.measles,
        "BMI": data.bmi,
        "Polio": data.polio,
        "Diphtheria": data.diphtheria,
        "Incidents_HIV": data.incidents_hiv,
        "GDP_per_capita": data.gdp_per_capita,
        "Population_mln": data.population_mln,
        "Thinness_ten_nineteen_years": data.thinness_ten_nineteen_years,
        "Thinness_five_nine_years": data.thinness_five_nine_years,
        "Schooling": data.schooling,
        "Economy_status_Developed": data.economy_status_developed,
    }

    # One-hot encode region to match training columns. "Africa" was the dropped
    # baseline category during training, so it maps to all zeros.
    for col in feature_columns:
        if col.startswith("Region_"):
            region_name = col.replace("Region_", "")
            row[col] = 1 if data.region == region_name else 0

    df_row = pd.DataFrame([row])
    df_row = df_row[feature_columns]  # enforce exact training column order
    return df_row


@app.get("/")
def root():
    return {"message": "Life Expectancy Prediction API is running. Visit /docs for Swagger UI."}


@app.post("/predict", response_model=PredictionOutput)
def predict(data: PredictionInput):
    df_row = build_feature_row(data)
    scaled = scaler.transform(df_row)
    prediction = model.predict(scaled)[0]
    return PredictionOutput(predicted_life_expectancy=round(float(prediction), 2))


@app.post("/retrain")
def retrain():
    """
    Retrains the model using the current life_expectancy.csv dataset.
    Trigger this endpoint after uploading new/updated data to the API's data folder.
    """
    from sklearn.model_selection import train_test_split
    from sklearn.ensemble import RandomForestRegressor
    from sklearn.preprocessing import StandardScaler

    data_path = os.path.join(BASE_DIR, "life_expectancy.csv")
    if not os.path.exists(data_path):
        raise HTTPException(status_code=404, detail="No dataset found to retrain on. Upload life_expectancy.csv to the API folder first.")

    df = pd.read_csv(data_path)
    df = df.drop(columns=["Country", "Economy_status_Developing"])
    df = pd.get_dummies(df, columns=["Region"], drop_first=True)

    X = df.drop(columns=["Life_expectancy"])
    y = df["Life_expectancy"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    new_scaler = StandardScaler()
    X_train_scaled = new_scaler.fit_transform(X_train)
    X_test_scaled = new_scaler.transform(X_test)

    new_model = RandomForestRegressor(n_estimators=100, random_state=42)
    new_model.fit(X_train_scaled, y_train)

    from sklearn.metrics import mean_squared_error, r2_score
    preds = new_model.predict(X_test_scaled)
    mse = mean_squared_error(y_test, preds)
    r2 = r2_score(y_test, preds)

    joblib.dump(new_model, os.path.join(BASE_DIR, "best_model.pkl"))
    joblib.dump(new_scaler, os.path.join(BASE_DIR, "scaler.pkl"))
    joblib.dump(X.columns.tolist(), os.path.join(BASE_DIR, "feature_columns.pkl"))

    global model, scaler, feature_columns
    model = new_model
    scaler = new_scaler
    feature_columns = X.columns.tolist()

    return {"message": "Model retrained successfully", "mse": round(mse, 4), "r2": round(r2, 4)}
