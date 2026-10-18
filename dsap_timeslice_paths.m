function config=dsap_timeslice_paths(root)
% Resolve local input locations only; no source/orientation validation changes.
if nargin<1,root=fileparts(mfilename('fullpath'));end
config=jsondecode(fileread(fullfile(root,'timeslice_config.json')));
fields={'realmPath','timesliceDbRoot'};overrides={'DSAP_TIMESLICE_REALM','DSAP_TIMESLICE_DB'};
for k=1:2
    value=getenv(overrides{k});
    if isempty(value),value=char(config.(fields{k}));end
    tokens=regexp(value,'%([^%]+)%','tokens');
    for j=1:numel(tokens)
        name=tokens{j}{1};expanded=getenv(name);
        assert(~isempty(expanded),'DSAP:TimesliceConfig','环境变量 %s 未设置。',name);
        value=strrep(value,['%' name '%'],expanded);
    end
    assert(~isempty(value),'DSAP:TimesliceConfig','TIMESlice 配置 %s 为空。',fields{k});
    absolute=~isempty(regexp(value,'^[A-Za-z]:[\\/]|^[\\/]{2}','once'));
    if ~absolute,value=fullfile(root,value);end
    config.(fields{k})=char(java.io.File(value).getCanonicalPath());
end
end
