# CSRF Protection Implementation Guide

## Overview

CSRF (Cross-Site Request Forgery) protection has been added via the `CsrfService` class. This guide explains how to implement it in your forms.

## What is CSRF?

CSRF attacks trick authenticated users into submitting requests they didn't intend to make. An attacker might create a malicious form on their site that submits to your application, exploiting the user's logged-in session.

## How CSRF Tokens Work

1. When rendering a form, generate a unique token and store it in the session
2. Include the token as a hidden field in the form
3. When the form is submitted, verify the token matches what's in the session
4. If valid, process the request; if invalid, reject it

## Usage

### In View Templates

Add a hidden field to every form that performs state-changing operations (POST, PUT, DELETE):

```php
<!-- php-app/src/Views/cases/create.php -->
<form method="POST" action="/cases/create">
    <!-- CSRF Token -->
    <input type="hidden" name="csrf_token" value="<?= \App\Services\CsrfService::generate() ?>">
    
    <!-- Your form fields -->
    <label>Case Name:</label>
    <input type="text" name="case_name" required>
    
    <button type="submit">Create Case</button>
</form>
```

### In Controllers

Validate the token before processing the request:

```php
// php-app/src/Controllers/CaseController.php
use App\Services\CsrfService;

public function create(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Validate CSRF token
        try {
            CsrfService::validateOrFail($_POST['csrf_token'] ?? null);
        } catch (RuntimeException $e) {
            http_response_code(403);
            echo "CSRF validation failed. Please try again.";
            return;
        }
        
        // Token is valid - proceed with processing
        $caseName = $_POST['case_name'] ?? '';
        // ... rest of your logic
    }
}
```

Alternative (returns boolean):

```php
if (!CsrfService::validate($_POST['csrf_token'] ?? null)) {
    http_response_code(403);
    echo "Invalid request. Please try again.";
    return;
}
```

## Forms That Need CSRF Protection

Implement CSRF tokens on these forms:

### High Priority (State-Changing Operations)
- [ ] `Views/cases/create.php` - Create case form
- [ ] `Views/cases/edit.php` - Edit case form
- [ ] `Views/cases/delete.php` - Delete case confirmation
- [ ] `Views/uploads/upload.php` - File upload form
- [ ] `Views/jobs/process.php` - Start processing form
- [ ] `Views/jobs/cancel.php` - Cancel job form
- [ ] `Views/results/delete.php` - Delete result form
- [ ] `Views/exports/create.php` - Create export form
- [ ] Any other POST/PUT/DELETE forms

### Safe to Skip (GET requests, Read-only)
- Login redirect (handled by Keycloak)
- Logout (can be CSRF-protected but low risk)
- Search forms (GET requests)
- Filter forms (GET requests)

## Best Practices

1. **Always use POST for state changes**
   - Never use GET for delete, create, or update operations
   - GET requests should be read-only

2. **One token per form submission**
   - The `validate()` method consumes the token (one-time use)
   - If form submission fails validation, generate a new token

3. **Multiple tabs support**
   - The service stores up to 10 tokens simultaneously
   - Users can have multiple forms open in different tabs

4. **Error handling**
   - Show user-friendly messages on CSRF failure
   - Log suspicious activity (multiple failed CSRF attempts)
   - Don't reveal technical details to users

5. **AJAX requests**
   - For AJAX, you can include the token in request headers:
   ```javascript
   fetch('/api/cases', {
       method: 'POST',
       headers: {
           'X-CSRF-Token': document.getElementById('csrf_token').value,
           'Content-Type': 'application/json'
       },
       body: JSON.stringify(data)
   });
   ```
   - Then validate in controller using: `$_SERVER['HTTP_X_CSRF_TOKEN']`

## Testing CSRF Protection

1. **Valid token test**:
   - Submit form normally - should succeed

2. **Missing token test**:
   - Remove the hidden field - should fail with 403

3. **Invalid token test**:
   - Change the token value - should fail with 403

4. **Replay attack test**:
   - Submit the same form twice with same token - second submit should fail

5. **Multiple tabs test**:
   - Open form in multiple tabs
   - Submit from each tab - all should succeed (within token limit)

## Migration Plan

To add CSRF protection to existing forms:

1. **Audit all forms** - List all forms that perform state changes
2. **Add tokens to views** - Update view templates with hidden field
3. **Add validation to controllers** - Update controller methods
4. **Test thoroughly** - Verify each form works correctly
5. **Monitor logs** - Watch for CSRF validation failures after deployment

## Example: Complete Implementation

### View (create_case.php)
```php
<?php use App\Services\CsrfService; ?>
<h1>Create New Case</h1>

<form method="POST" action="/cases/store">
    <input type="hidden" name="csrf_token" value="<?= CsrfService::generate() ?>">
    
    <div>
        <label>Case Number:</label>
        <input type="text" name="case_number" required>
    </div>
    
    <div>
        <label>Description:</label>
        <textarea name="description"></textarea>
    </div>
    
    <button type="submit">Create Case</button>
</form>
```

### Controller (CaseController.php)
```php
use App\Services\CsrfService;

public function store(): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        return;
    }
    
    // Validate CSRF token
    if (!CsrfService::validate($_POST['csrf_token'] ?? null)) {
        AuditService::log('case_create_csrf_fail', ['ip' => $_SERVER['REMOTE_ADDR']]);
        http_response_code(403);
        echo "Security validation failed. Please try again.";
        return;
    }
    
    // Validate input
    $caseNumber = trim($_POST['case_number'] ?? '');
    if (empty($caseNumber)) {
        echo "Case number is required.";
        return;
    }
    
    // Create the case
    try {
        $caseId = $this->caseRepository->create([
            'case_number' => $caseNumber,
            'description' => $_POST['description'] ?? '',
            'created_by' => $_SESSION['user_id'],
        ]);
        
        AuditService::log('case_created', ['case_id' => $caseId]);
        header('Location: /cases/' . $caseId);
    } catch (Exception $e) {
        http_response_code(500);
        echo "Failed to create case.";
    }
}
```

## Security Considerations

- **Token entropy**: Tokens use 32 bytes of random data (256 bits), making them cryptographically secure
- **Storage**: Tokens are stored in PHP sessions, which should use secure session settings
- **Transmission**: Tokens are sent via POST body, not in URLs
- **HTTPS**: Always use HTTPS in production to prevent token interception
- **Session fixation**: Regenerate session ID after login (handled by Keycloak)

## Troubleshooting

**"CSRF validation failed" after legitimate submission**:
- Check that session is active (`session_status() === PHP_SESSION_ACTIVE`)
- Verify session cookie is being sent
- Check browser cookie settings (must allow cookies)
- Ensure session lifetime hasn't expired

**Token works first time but not on retry**:
- This is expected - tokens are one-time use
- Regenerate the form with a new token on validation errors

**Multiple tabs don't work**:
- Check `MAX_TOKENS` setting in CsrfService
- Increase limit if users commonly work with many tabs

## Further Reading

- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [PHP Session Security](https://www.php.net/manual/en/session.security.php)
