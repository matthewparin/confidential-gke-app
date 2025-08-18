from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello_confidential_world():
    """
    This endpoint returns a simple JSON message to confirm the app is running.
    """
    return jsonify({
        "message": "Hello from a Confidential GKE container!"
    })

if __name__ == '__main__':
    # The application will be served by Gunicorn in the container,
    # but this block allows for local testing.
    # It listens on all available network interfaces (0.0.0.0).
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))