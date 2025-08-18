# 1. Base Image: Start from an official, lightweight Python image.
# 'slim-buster' is a good balance of size and functionality.
FROM python:3.9-slim-buster

# 2. Working Directory: Set the working directory inside the container.
# All subsequent commands will be run from this directory.
WORKDIR /app

# 3. Copy Dependencies: Copy the requirements file first.
# This leverages Docker's layer caching. The dependencies layer is only
# rebuilt if requirements.txt changes, not on every code change.
COPY app/requirements.txt requirements.txt

# 4. Install Dependencies: Install the Python packages.
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy Application Code: Copy the rest of the application code.
COPY app/ .

# 6. Expose Port: Inform Docker that the container listens on port 5000.
# This is metadata and does not actually publish the port.
EXPOSE 5000

# 7. Run Command: Specify the command to run when the container starts.
# Use gunicorn for a production-ready WSGI server, which was added
# to our requirements.txt file.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]