# One image, several Lambda functions: the CDK stacks pick the entrypoint per
# function (API: app.lambda_handler.handler, workers: workers.<module>.handler).
FROM public.ecr.aws/lambda/python:3.11

COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r requirements.txt

COPY app ${LAMBDA_TASK_ROOT}/app
COPY workers ${LAMBDA_TASK_ROOT}/workers
COPY alembic ${LAMBDA_TASK_ROOT}/alembic
COPY alembic.ini ${LAMBDA_TASK_ROOT}/alembic.ini

CMD ["app.lambda_handler.handler"]
