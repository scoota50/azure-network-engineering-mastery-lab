import json
import logging

import azure.functions as func

app = func.FunctionApp()


@app.route(
    route="health",
    methods=["GET"],
    auth_level=func.AuthLevel.ANONYMOUS
)
def health(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Gatekeeper health endpoint called")

    return func.HttpResponse(
        json.dumps({
            "status": "ok",
            "service": "gatekeeper"
        }),
        status_code=200,
        mimetype="application/json"
    )
