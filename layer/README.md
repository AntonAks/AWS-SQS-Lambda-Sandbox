# Lambda Layer

This directory contains the requirements for the Lambda layer that provides shared dependencies for all Lambda functions in the project.

## Contents

- `requirements.txt` - Python dependencies to be included in the layer

## Usage

The layer is automatically built and deployed by the Makefile:

```bash
make package-layer
```

This will:
1. Create a `python/` directory
2. Install all dependencies from `requirements.txt` into `python/`
3. Create a ZIP archive at `../dist/python_layer.zip`
4. Clean up the temporary `python/` directory

## Dependencies

The layer includes:
- `boto3` - AWS SDK for Python
- `botocore` - Low-level AWS service interfaces
- `requests` - HTTP library for API testing

## Layer Structure

When deployed, the layer provides dependencies at:
```
/opt/python/
├── boto3/
├── botocore/
├── requests/
└── ... (other dependencies)
```

Lambda functions can import these dependencies directly without including them in their deployment packages.