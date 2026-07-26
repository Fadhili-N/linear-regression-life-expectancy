# Life Expectancy Prediction
Many African countries face preventable gaps in life expectancy tied to measurable factors like immunization rates, adult mortality, and access to schooling, but this data rarely gets turned into forward-looking tools. This project trains a regression model on WHO health and economic indicators to predict life expectancy, then deploys it as a public API and mobile app so the prediction is usable outside a notebook, not just in a research setting.

Dataset: [Life Expectancy (WHO) Fixed](https://www.kaggle.com/datasets/lashagoch/life-expectancy-who-updated) by lashagoch on Kaggle, 2,864 rows across 21 indicators (mortality, immunization, economic, and social factors) spanning 2000-2015.

## Live API

Public URL: https://linear-regression-life-expectancy.onrender.com
Swagger UI (interactive docs): https://linear-regression-life-expectancy.onrender.com/docs

Note: the free Render tier spins down after inactivity, so the first request after a while may take 30-60 seconds to respond while it wakes up.

## Video Demo

https://youtu.be/ROQevtnxdnc

## Project Structure
linear_regression_model/
├── summative/
│   ├── linear_regression/
│   │   └── multivariate.ipynb       # data exploration, feature engineering, model training/comparison
│   ├── API/
│   │   ├── prediction.py            # FastAPI app: /predict and /retrain endpoints
│   │   └── requirements.txt
│   ├── FlutterApp/                  # mobile app (lib/main.dart)
│   └── pyproject.toml


## Models Compared

Four regression approaches were trained and compared on the same train/test split:

| Model | MSE | R² |
|---|---|---|
| Random Forest (best) | 0.226 | 0.997 |
| Decision Tree | 0.567 | 0.993 |
| Linear Regression | 1.474 | 0.982 |
| SGD Regression | 1.494 | 0.982 |

Random Forest was saved as the production model based on lowest test MSE and highest R².

## Running the Mobile App

Requirements: Flutter SDK installed, an Android emulator or physical device connected.

```bash
cd summative/FlutterApp
flutter pub get
flutter run
```

The app has one screen: input fields for every model variable (with valid ranges shown), a region and economy status dropdown, a Predict button, and a result area. It calls the live Render API above, no local backend needed.

## Running the API Locally (optional)

```bash
cd summative/API
pip install -r requirements.txt
uvicorn prediction:app --reload
```

Then visit `http://127.0.0.1:8000/docs`.
