FROM public.ecr.aws/lambda/python:3.12

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Download AWS RDS CA certificate
RUN curl -o ${LAMBDA_TASK_ROOT}/rds-ca-2019-root.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Copy entrypoint script
COPY entrypoint.sh ${LAMBDA_TASK_ROOT}
RUN chmod +x ${LAMBDA_TASK_ROOT}/entrypoint.sh

# Set the default CMD to lambda handler, but allow override
CMD [ "lambda_function.handler" ]

# When running in ECS, use the entrypoint script
ENTRYPOINT ["/var/task/entrypoint.sh"]