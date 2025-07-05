public without sharing class TableauJwtService {

    // --- !!! SECURITY WARNING !!! ---
    // HARDCODING SECRETS IS A MAJOR SECURITY RISK.
    // REPLACE THESE WITH SECURE STORAGE (Custom Metadata, Custom Settings)
    // BEFORE ANY PRODUCTION USE.
    // --------------------------------
    private static final String HARDCODED_CLIENT_ID = 'a42607aa-b1e5-4b5b-a0c3-958336d1c12e'; // <-- REPLACE with your actual Client ID
    private static final String HARDCODED_SECRET_VALUE = 'fYwtVZ3I0wlsKsKi1cdOVdPdgORc2GVSHeNUaNkww8A='; // <-- REPLACE with your actual Secret Value
    // You might also need the Secret ID depending on your Connected App configuration
    // private static final String HARDCODED_SECRET_ID = 'f27a4505-bc94-4b97-9c8f-33028bb872dd'; // <-- REPLACE if needed and configure 'kid' claim

    /**
     * Generates a JSON Web Token (JWT) for embedding Tableau content.
     * This method uses hardcoded credentials for quick setup - REPLACE BEFORE PRODUCTION.
     * @param tableauUsername The username of the Tableau Cloud user (case-sensitive).
     * @return A signed JWT string.
     */
    @AuraEnabled(cacheable=false) // cacheable=false because the token changes
    public static String generateEmbeddingJwt(String tableauUsername) {

        if (String.isBlank(tableauUsername)) {
             throw new AuraHandledException('Tableau username cannot be blank.');
        }

        // 1. Retrieve Credentials (using hardcoded values TEMPORARILY)
        String clientId = HARDCODED_CLIENT_ID;
        String secretValue = HARDCODED_SECRET_VALUE;
        // String secretId = HARDCODED_SECRET_ID; // Use if 'kid' claim is needed

        // 2. Construct Header
        Map<String, Object> header = new Map<String, Object>{
            'alg' => 'HS256', // Algorithm must match your Connected App configuration (Direct Trust typically uses HS256)
            'typ' => 'JWT'
        };
        // If you used a Secret ID and need the 'kid' claim in the JWT header:
        // header.put('kid', secretId);

        String encodedHeader = base64UrlEncode(JSON.serialize(header));

        // 3. Construct Payload (Claims)
        Long currentTime = DateTime.now().getTime() / 1000;
        // Current time in seconds
        Map<String, Object> claims = new Map<String, Object>{
            'sub' => tableauUsername,     // Tableau Cloud username (case-sensitive)
            'iss' => clientId,            // Your Client ID
            'aud' => 'tableau',           // Audience is 'tableau'
            'exp' => currentTime + 300    // Expiration time (e.g., 300 seconds = 5 minutes from now)
            // 'jti' => String.valueOf(Crypto.getRandomGuid()) // Optional: Unique token ID
        };
        String encodedPayload = base64UrlEncode(JSON.serialize(claims));

        // Combine header and payload for signing
        String unsignedToken = encodedHeader + '.' + encodedPayload;

        // 4. Sign the Token using the Secret Value
        Blob key = EncodingUtil.base64Decode(secretValue); // Decode the Base64 Secret Value
        Blob signature = Crypto.generateMac('HMACSHA256', Blob.valueOf(unsignedToken), key);
        String encodedSignature = base64UrlEncode(signature); // Use the Blob version of helper

        // 5. Combine parts into the final JWT
        String jwt = unsignedToken + '.' + encodedSignature;

        System.debug('Generated JWT for user ' + tableauUsername + ': ' + jwt);
        return jwt;
    }

    // Helper method for Base64Url encoding (String input)
    private static String base64UrlEncode(String input) {
        String output = EncodingUtil.base64Encode(Blob.valueOf(input));
        // Replace URL-unsafe characters according to Base64Url spec
        return output.replace('+', '-').replace('/', '_').replace('=', '');
    }

     // Helper method for Base64Url encoding (Blob input)
     private static String base64UrlEncode(Blob input) {
        String output = EncodingUtil.base64Encode(input);
        // Replace URL-unsafe characters according to Base64Url spec
        return output.replace('+', '-').replace('/', '_').replace('=', '');
    }
}