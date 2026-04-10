<?php
/**
 * php-app/src/Services/PythonApiClient.php
 * ------------------------------------------
 * HTTP client for the Python FastAPI backend.
 *
 * Plain-language:
 *   The PHP app cannot do audio transcription itself – that lives in Python.
 *   This service sends HTTP requests to the Python API (running at
 *   PYTHON_API_BASE_URL in the .env file) and returns the parsed responses.
 *
 *   The X-Api-Key header is sent on every request so the Python side can
 *   verify that the request comes from our PHP app and not from the internet.
 */

declare(strict_types=1);

namespace App\Services;

use App\Config\Config;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Exception\RequestException;
use RuntimeException;

class PythonApiClient
{
    private Client $http;
    private string $baseUrl;

    public function __construct()
    {
        $this->baseUrl = Config::get('python_api.base_url');
        $this->http    = new Client([
            'base_uri' => $this->baseUrl,
            'timeout'  => 30,
            'headers'  => [
                'X-Api-Key'    => Config::get('python_api.api_key'),
                'Accept'       => 'application/json',
                'Content-Type' => 'application/json',
            ],
        ]);
    }

    /**
     * Check Python API health.
     *
     * @return array<string,mixed>
     */
    public function health(): array
    {
        return $this->get('/api/health');
    }

    /**
     * Upload an audio file to MinIO via the Python API.
     *
     * @param  string $filePath    Absolute path to the local temp file
     * @param  string $fileName    Original file name (for extension detection)
     * @param  int    $caseId      PostgreSQL case ID
     * @return array{minio_bucket: string, minio_path: string, size_bytes: int, sha256: string, original_filename: string}
     */
    public function uploadAudio(string $filePath, string $fileName, int $caseId): array
    {
        try {
            $response = $this->http->post('/api/upload', [
                'multipart' => [
                    [
                        'name'     => 'file',
                        'contents' => fopen($filePath, 'r'),
                        'filename' => $fileName,
                    ],
                    [
                        'name'     => 'case_id',
                        'contents' => (string) $caseId,
                    ],
                ],
                // Remove Content-Type so Guzzle sets the correct multipart boundary
                'headers' => ['Content-Type' => null],
            ]);
        } catch (RequestException $e) {
            $body = $e->hasResponse() ? (string) $e->getResponse()->getBody() : '';
            throw new RuntimeException("Upload failed: {$body}");
        } catch (GuzzleException $e) {
            throw new RuntimeException("Upload request error: {$e->getMessage()}");
        }

        return $this->parseJson($response);
    }

    /**
     * Start a transcription job.
     *
     * @param  array<string,mixed> $params
     * @return array{job_id: int, celery_task_id: string, status: string}
     */
    public function startProcessing(array $params): array
    {
        return $this->post('/api/process', $params);
    }

    /**
     * Poll job status.
     *
     * @return array{job_id: int, status: string, progress: int, events: array, error_message: string|null}
     */
    public function getJobStatus(int $jobId): array
    {
        return $this->get("/api/job/{$jobId}/status");
    }

    /**
     * Retrieve job result.
     *
     * @return array<string,mixed>
     */
    public function getJobResult(int $jobId): array
    {
        return $this->get("/api/job/{$jobId}/result");
    }

    // -----------------------------------------------------------------------
    // Private HTTP helpers
    // -----------------------------------------------------------------------

    /** @return array<string,mixed> */
    private function get(string $path): array
    {
        try {
            $response = $this->http->get($path);
        } catch (RequestException $e) {
            $body = $e->hasResponse() ? (string) $e->getResponse()->getBody() : '';
            throw new RuntimeException("GET {$path} failed: {$body}");
        } catch (GuzzleException $e) {
            throw new RuntimeException("GET {$path} error: {$e->getMessage()}");
        }
        return $this->parseJson($response);
    }

    /**
     * @param  array<string,mixed> $data
     * @return array<string,mixed>
     */
    private function post(string $path, array $data): array
    {
        try {
            $response = $this->http->post($path, ['json' => $data]);
        } catch (RequestException $e) {
            $body = $e->hasResponse() ? (string) $e->getResponse()->getBody() : '';
            throw new RuntimeException("POST {$path} failed: {$body}");
        } catch (GuzzleException $e) {
            throw new RuntimeException("POST {$path} error: {$e->getMessage()}");
        }
        return $this->parseJson($response);
    }

    /** @return array<string,mixed> */
    private function parseJson(\Psr\Http\Message\ResponseInterface $response): array
    {
        $body = (string) $response->getBody();
        $data = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
        return is_array($data) ? $data : ['raw' => $data];
    }
}
