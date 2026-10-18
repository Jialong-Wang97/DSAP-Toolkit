function [full_field,job]=dsap_cave_full_field(source_file,shape,polarity,showProgress)
% Existing CAVE worker/cache adapter, independent of AIF and analysis scope.
    root=fileparts(mfilename('fullpath'));
    dsap_require_dependency('cave');
    identity=dsap_source_identity(source_file);
    lockGuard=dsap_preparation_lock(fullfile(root,'outputs','preparation_locks'),identity.SHA256); %#ok<NASGU>
    python=fullfile(root,'.venv_cave','Scripts','pythonw.exe');
    worker=fullfile(root,'scripts','cave_worker.py');
    if ~isfile(python)||~isfile(worker)
        error('DSAP:CAVEUnavailable','CAVE 本机运行环境缺失；未自动改用旧方法。');
    end
    if ~strcmp(polarity,'dark')
        error('DSAP:CAVEInput','CAVE 当前仅验证暗血管输入；可明确选择旧 DCA 方法处理其他输入。');
    end
    own_control=~dsap_task_control('active');
    if own_control
        dsap_task_control('begin','off');
        control_cleanup=onCleanup(@() dsap_task_control('finish')); %#ok<NASGU>
    end
    dsap_task_control('check');
    job=fullfile(root,'outputs','cave_jobs',char(java.util.UUID.randomUUID()));mkdir(job);
    request=struct('source_file',char(source_file),'image_size',shape,'polarity',polarity);
    fid=fopen(fullfile(job,'request.json'),'w','n','UTF-8');
    assert(fid~=-1,'无法建立 CAVE 请求文件。');
    close_request=onCleanup(@() fclose(fid));
    fprintf(fid,'%s',jsonencode(request));clear close_request;
    command={python,worker,'--job',job,'--cache',fullfile(root,'outputs','cave_cache'), ...
        '--parent-pid',num2str(feature('getpid'))};
    argv=javaArray('java.lang.String',numel(command));
    for k=1:numel(command),argv(k)=java.lang.String(command{k});end
    builder=java.lang.ProcessBuilder(argv);
    builder.redirectErrorStream(true);
    builder.redirectOutput(java.io.File(fullfile(job,'worker.log')));
    process=builder.start();
    process_cleanup=onCleanup(@() stop_worker(process)); %#ok<NASGU>
    progress=[];
    if showProgress
        progress=dsap_progress(0,'准备 CAVE；首次 CPU 推理可能需要约 2 分钟，可随时取消','CAVE 血管分割');
    end
    progress_cleanup=onCleanup(@() dsap_safe_delete(progress)); %#ok<NASGU>
    started=tic;last_update=-1;
    while process.isAlive()
        dsap_task_control('check');
        drawnow limitrate;
        if toc(started)>900
            error('DSAP:CAVETimeout','CAVE 超过 15 分钟仍未完成，本次推理已停止。');
        end
        if ~isempty(progress)&&isgraphics(progress)&&toc(started)-last_update>0.3
            last_update=toc(started);
            try
                state=jsondecode(fileread(fullfile(job,'progress.json')));
                waitbar(min(max(state.fraction,0),1),progress,sprintf('%s | 已用 %.0f 秒',state.stage,toc(started)));
            catch
                % Atomic status replacement may briefly race with this read.
            end
        end
        pause(0.1);
    end
    dsap_task_control('check');
    error_file=fullfile(job,'error.json');
    if isfile(error_file)
        failure=jsondecode(fileread(error_file));
        error('DSAP:CAVEFailed','CAVE 未完成：%s\n日志：%s',failure.message,job);
    end
    if process.exitValue()~=0||~isfile(fullfile(job,'done.json'))||~isfile(fullfile(job,'result.mat'))
        error('DSAP:CAVEFailed','CAVE 子进程异常结束，未采用不完整结果。日志：%s',job);
    end
    result=load(fullfile(job,'result.mat'));
    provenance=jsondecode(result.metadata_json);
    assert(provenance.complete&&strcmp(provenance.method,'CAVE-AV-union'),'CAVE 完成状态无效。');
    assert(isequal(size(result.artery_mask),shape)&&isequal(size(result.vein_mask),shape),'CAVE 输出尺寸不符。');
    raw=logical(result.artery_mask)|logical(result.vein_mask);
    full_field=struct('ArteryMask',logical(result.artery_mask),'VeinMask',logical(result.vein_mask), ...
        'UnionMask',raw,'Provenance',provenance);
end

function stop_worker(process)
    if process.isAlive()
        process.destroyForcibly();
    end
end
