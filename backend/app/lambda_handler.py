"""AWS Lambda entrypoint: API Gateway (REST, proxy) -> FastAPI via Mangum."""

from mangum import Mangum

from app.main import app

handler = Mangum(app, lifespan="off")
