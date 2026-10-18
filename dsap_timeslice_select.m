function [source,entries,cancelled,provenance]=dsap_timeslice_select(root,select_series)
% Fresh read-only database export for every selection; never stale fallback.
    dsap_require_dependency('legacy');
    if nargin<2,select_series=@listdlg;end
    source='';entries=struct([]);cancelled=true;provenance=struct();
    config=dsap_timeslice_paths(root);
    assert(isfile(config.realmPath)&&isfolder(config.timesliceDbRoot), ...
        'DSAP:TimesliceConfig','TIMESlice Realm / 数据目录不存在。请设置 timeslice_config.json 或 DSAP_TIMESLICE_REALM / DSAP_TIMESLICE_DB。');
    node=fullfile(root,'cave_runtime','node.exe');
    assert(isfile(node),'TIMESlice 导入所需 Node 运行库缺失。');
    job=fullfile(root,'outputs','timeslice_import',char(java.util.UUID.randomUUID()));mkdir(job);
    output=fullfile(job,'current_rois.json');
    args={node,fullfile(root,'timeslice_realm_reader','export_cave_current_rois.js'), ...
        config.realmPath,config.timesliceDbRoot,output};
    argv=javaArray('java.lang.String',numel(args));
    for k=1:numel(args),argv(k)=java.lang.String(args{k});end
    builder=java.lang.ProcessBuilder(argv);builder.redirectErrorStream(true);
    builder.redirectOutput(java.io.File(fullfile(job,'export.log')));
    process=builder.start();cleanup=onCleanup(@() stop_process(process)); %#ok<NASGU>
    started=tic;
    while process.isAlive()
        dsap_task_control('check');pause(.1);
        if toc(started)>60,error('DSAP:TimesliceTimeout','读取 TIMESlice 数据库超时。');end
    end
    assert(process.exitValue()==0&&isfile(output), ...
        '读取 TIMESlice 当前 ROI 失败；未采用旧索引。请保存 ROI 后重试。日志：%s',job);
    catalog=jsondecode(fileread(output));
    assert(~isempty(catalog.entries),'未找到具有唯一影像及当前掩膜的 ROI。日志：%s',job);
    all_entries=catalog.entries;
    files=unique({all_entries.dicomFile},'stable');labels=cell(size(files));
    for k=1:numel(files)
        item=all_entries(find(strcmp({all_entries.dicomFile},files{k}),1));
        labels{k}=sprintf('患者 %s | Series %s | %d 个当前 ROI | %s', ...
            item.patientId,item.seriesNumber,nnz(strcmp({all_entries.dicomFile},files{k})),item.stackId);
    end
    if ~isempty(catalog.skipped)
        warning('DSAP:TimesliceSkipped','%d 条记录缺少当前掩膜或影像文件不唯一，未猜测匹配。日志：%s',numel(catalog.skipped),job);
    end
    [selection,ok]=select_series('Name','TIMESlice 当前保存 ROI','PromptString', ...
        {'每次均重新读取当前 ROI.step，不按历史文件时间选择。','请先在 TIMESlice 保存修改；未保存的界面操作无法读取。'}, ...
        'ListString',labels,'SelectionMode','single','ListSize',[950 360]);
    if ~ok,return;end
    source=files{selection};entries=all_entries(strcmp({all_entries.dicomFile},source));
    provenance=rmfield(catalog,{'entries','skipped'});provenance.SnapshotFile=output;
    provenance.SelectedStackSkipped=struct([]);
    if ~isempty(catalog.skipped)
        provenance.SelectedStackSkipped=catalog.skipped(strcmp({catalog.skipped.stackId},entries(1).stackId));
    end
    cancelled=false;
end

function stop_process(process)
    if process.isAlive(),process.destroyForcibly();end
end
