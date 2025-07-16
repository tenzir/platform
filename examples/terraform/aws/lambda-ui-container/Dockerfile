FROM public.ecr.aws/lambda/nodejs:22

# Copy package.json
COPY package*.json ${LAMBDA_TASK_ROOT}

# Install dependencies
RUN npm install --only=production

# Copy function code
COPY index.js ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "index.handler" ]