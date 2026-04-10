<?php
/**
 * API Client for communicating with Python backend
 */

class ApiClient
{
    private $baseUrl;
    private $apiKey;
    private $timeout;

    public function __construct($config)
    {
        $this->baseUrl = rtrim($config['base_url'], '/');
        $this->apiKey = $config['secret_key'];
        $this->timeout = $config['timeout'] ?? 30;
    }

    /**
     * Make API request
     */
    private function request($method, $endpoint, $data = null, $files = null)
    {
        $url = $this->baseUrl . '/' . ltrim($endpoint, '/');
        
        $ch = curl_init();
        
        $headers = [
            'X-Api-Key: ' . $this->apiKey,
        ];
        
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $this->timeout);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        
        if ($method === 'POST') {
            curl_setopt($ch, CURLOPT_POST, true);
            
            if ($files !== null) {
                // Multipart form data for file uploads
                curl_setopt($ch, CURLOPT_POSTFIELDS, $files);
            } elseif ($data !== null) {
                $headers[] = 'Content-Type: application/json';
                curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            }
        } elseif ($method === 'GET' && $data !== null) {
            $url .= '?' . http_build_query($data);
            curl_setopt($ch, CURLOPT_URL, $url);
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        
        curl_close($ch);
        
        if ($error) {
            throw new Exception('API request failed: ' . $error);
        }
        
        $result = json_decode($response, true);
        
        if ($httpCode >= 400) {
            $errorMsg = $result['detail'] ?? 'API request failed';
            throw new Exception($errorMsg);
        }
        
        return $result;
    }

    /**
     * Upload audio file
     */
    public function uploadAudio($filePath, $jobId)
    {
        if (!file_exists($filePath)) {
            throw new Exception('File not found: ' . $filePath);
        }
        
        $cfile = new CURLFile($filePath, mime_content_type($filePath), basename($filePath));
        
        $data = [
            'file' => $cfile,
            'job_id' => $jobId,
        ];
        
        return $this->request('POST', '/upload/', null, $data);
    }

    /**
     * Get job status
     */
    public function getJobStatus($jobId)
    {
        return $this->request('GET', "/jobs/{$jobId}/status");
    }

    /**
     * Get job details
     */
    public function getJobDetails($jobId)
    {
        return $this->request('GET', "/jobs/{$jobId}");
    }

    /**
     * Get transcript in JSON format
     */
    public function getTranscriptJson($jobId)
    {
        return $this->request('GET', "/transcripts/{$jobId}/json");
    }

    /**
     * Get transcript in text format
     */
    public function getTranscriptText($jobId)
    {
        $url = $this->baseUrl . "/transcripts/{$jobId}/txt";
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, $this->timeout);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'X-Api-Key: ' . $this->apiKey,
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode >= 400) {
            throw new Exception('Failed to retrieve transcript');
        }
        
        return $response;
    }
}
