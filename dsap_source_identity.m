function identity=dsap_source_identity(path)
% A filename/UID is not a content identity. Hash bytes without DICOM decoding.
    before=dir(path);assert(isscalar(before),'DSAP:SourceMissing','找不到唯一的 DICOM 文件。');
    fid=fopen(path,'rb');assert(fid>=0,'DSAP:SourceRead','无法读取 DICOM 来源。');
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    digest=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid),digest.update(fread(fid,4*1024^2,'*uint8'));end
    after=dir(path);
    assert(before.bytes==after.bytes&&before.datenum==after.datenum,'DSAP:SourceChanged','读取期间来源文件发生变化。');
    bytes=typecast(digest.digest(),'uint8');
    identity=struct('Path',char(java.io.File(path).getCanonicalPath()), ...
        'SHA256',lower(reshape(dec2hex(bytes,2).',1,[])),'Bytes',after.bytes,'Modified',after.datenum);
end
