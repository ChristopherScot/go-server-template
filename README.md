# Go Server Template

This repository serves as a skeleton for a Go server application. It includes a basic project structure, Dockerfile, and GitHub Actions workflow for building and deploying the application.

## Prerequisites

- Go 1.22 or later
- Docker

## Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/go-server-template.git
    cd go-server-template
    ```

2. Build the application:
    ```sh
    go build -o bin/app
    ```

## Usage

1. Build the Docker image:
    ```sh
    docker build -t go-server-template .
    ```

2. Run the Docker container:
    ```sh
    docker run -p 3000:3000 go-server-template
    ```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. 