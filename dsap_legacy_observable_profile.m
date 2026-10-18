function observed=dsap_legacy_observable_profile(entries,provenance)
% Observe raw headers BEFORE any mask transformation. No color inputs.
    assert(isfield(provenance,'SchemaVersion')&&startsWith(provenance.SchemaVersion,'realm-sha256:'), ...
        'DSAP:OrientationProfile','Observable Realm schema is required.');
    root=fileparts(mfilename('fullpath'));job=tempname;mkdir(job);
    cleanup=onCleanup(@() rmdir(job,'s')); %#ok<NASGU>
    input=fullfile(job,'input.json');output=fullfile(job,'output.json');
    fid=fopen(input,'w');assert(fid>=0);fwrite(fid,jsonencode({entries.maskFile}),'char');fclose(fid);
    args={fullfile(root,'cave_runtime','node.exe'),fullfile(root,'timeslice_realm_reader','read_observable_profile.js'),input,output};
    argv=javaArray('java.lang.String',numel(args));
    for k=1:numel(args),argv(k)=java.lang.String(args{k});end
    builder=java.lang.ProcessBuilder(argv);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(fullfile(job,'log.txt')));
    process=builder.start();code=process.waitFor();
    assert(code==0&&isfile(output),'DSAP:OrientationProfile','Cannot inspect NIfTI profile: %s',fileread(fullfile(job,'log.txt')));
    observed=jsondecode(fileread(output));
    for k=1:numel(observed)
        observed(k).RealmSchemaSHA=extractAfter(provenance.SchemaVersion,'realm-sha256:');
    end
end
