FROM public.ecr.aws/lambda/nodejs:22

# Copy package.json
COPY package*.json ${LAMBDA_TASK_ROOT}

# Install dependencies
RUN npm install --only=production

# Download AWS RDS CA certificate
RUN curl -o ${LAMBDA_TASK_ROOT}/rds-ca-2019-root.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# Copy function code
COPY index.js ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "index.handler" ]