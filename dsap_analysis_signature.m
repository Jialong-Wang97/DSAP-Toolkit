function signature=dsap_analysis_signature(value)
% Process-local dependency signatures; preserve MATLAB classes/shapes/precision.
    digest=java.security.MessageDigest.getInstance('SHA-256');
    digest.update(getByteStreamFromArray(value));
    bytes=typecast(digest.digest(),'uint8');signature=lower(reshape(dec2hex(bytes,2).',1,[]));
end
