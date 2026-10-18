function output_dir = run_interactive_perfusion_remove_large_vessels(replay,cache_options)
%RUN_INTERACTIVE_PERFUSION_REMOVE_LARGE_VESSELS DSA perfusion analysis
% with the verified CAVE artery/vein union and manual exclusion review.
%
% Select a folder or one multi-frame DICOM file and draw an arterial input
% function (AIF) ROI. Tissue statistics use automatically detected sustained
% enhancement within manual vertical limits, excluding large vessels/AIF.
% Results are displayed and saved under interactive_results.

    dsap_require_dependency('perfusion');
    if nargin<1, replay=struct(); end
    if nargin<2,cache_options=struct();end
    defaults=struct('Enabled',false,'RAMBudgetMiB',768,'DiskBudgetMiB',4096);
    for key=fieldnames(defaults)',if ~isfield(cache_options,key{1}),cache_options.(key{1})=defaults.(key{1});end,end
    dsap_analysis_session('release');
    output_dir='';
    if isempty(fieldnames(replay))
        dsap_task_control('begin');
        cleanup_task=onCleanup(@() dsap_task_control('finish')); %#ok<NASGU>
    end
    try
        output_dir=run_workflow(replay,cache_options);
    catch ME
        if dsap_workspace_bridge('active')
            ws=dsap_workspace_bridge('get');dsap_workspace_log_error(ws.Figure,ME,'run_workflow');
        end
        if strcmp(ME.identifier,'DSAP:Cancelled') || dsap_task_control('cancelled')
            dsap_workspace_bridge('activity','Cancelled','','本次操作已取消');
            fprintf('DSAP：已停止本次分析；未改动历史结果。\n');
            return;
        end
        if isempty(fieldnames(replay)) && ~dsap_workspace_bridge('active')
            errordlg(sprintf('分析失败：\n%s', ME.message), 'DSA 灌注分析');
        end
        rethrow(ME);
    end
end

function output_dir = run_workflow(replay,cache_options)
    workflow_started=tic;
    output_dir='';
    is_replay=~isempty(fieldnames(replay));
    use_partition=~is_replay || isfield(replay,'Partition');
    use_manual=is_replay&&isfield(replay,'ManualTissue');
    partition=struct();if use_manual,partition=replay.ManualTissue;use_partition=false;end
    timeslice_import=struct();use_imported=is_replay&&isfield(replay,'TimesliceImport');
    if use_imported,use_partition=false;timeslice_import=replay.TimesliceImport;end
    if isfield(replay,'VesselMethod')&&~strcmp(replay.VesselMethod,'cave')
        error('DSAP:RemovedLegacy','仅保留 CAVE 分割，旧 DCA 已移除。');
    end
    if is_replay && isfield(replay,'VesselCenterlineMode') && ~strcmp(replay.VesselCenterlineMode,'off')
        error('DSAP:RemovedFeature','中心线及管状重建功能已移除。请删除旧回放中的 VesselCenterlineMode 设置后重新分析。');
    end
    project_dir = fileparts(mfilename('fullpath'));
    addpath(project_dir);

    if dsap_workspace_bridge('active') && ~is_replay
        ws=dsap_workspace_bridge('source');source_file=ws.SourceFile;
        [source_folder,stem,extension]=fileparts(source_file);filename=[stem extension];
        input_mode_name='NativeDSAP-Workspace';use_imported=ws.Legacy;use_partition=~use_imported;
        if use_imported,timeslice_entries=ws.Entries;timeslice_provenance=ws.Origin;input_mode_name='TIMESlice';end
    elseif is_replay
        source_file=replay.SourceFile;
        [source_folder,stem,extension]=fileparts(source_file);
        filename=[stem extension];
        input_mode_name='saved-AIF-signal-quality-preview';
    else
    input_options = {'整个 DICOM 文件夹（浏览并选择序列）', ...
        '单个多帧 DICOM（手动画 ROI）', ...
        'TIMESlice（复用已保存 ROI 和 AIF）', ...
        'TIMESlice（仅选择序列，手动画 AIF/分区）'};
    [input_selection, accepted] = listdlg('PromptString', ...
        {'请选择 DSA 与 ROI 的来源：', ...
         '文件夹模式会先显示所有多帧 DSA 序列的缩略图。'}, ...
        'SelectionMode', 'single', 'ListString', input_options, ...
        'InitialValue', 1, 'ListSize', [500 170], 'Name', 'DSA 灌注分析');
    if ~accepted
        return;
    end
    use_timeslice = ismember(input_selection,[3 4]);
    use_imported = input_selection == 3;
    if use_imported,use_partition=false;end
    use_folder_browser = input_selection == 1;
    input_mode_name = 'manual-file';
    source_folder = '';

    if use_timeslice
        input_mode_name = 'TIMESlice';
        [source_file,timeslice_entries,cancelled,timeslice_provenance] = dsap_timeslice_select(project_dir);
        if cancelled
            return;
        end
        [~, filename, extension] = fileparts(source_file);
        filename = [filename, extension];
    elseif use_folder_browser
        input_mode_name = 'manual-folder';
        [source_file, source_folder, cancelled] = ...
            select_dicom_from_folder(project_dir);
        if cancelled
            return;
        end
        [~, filename, extension] = fileparts(source_file);
        filename = [filename, extension];
    else
        [filename, pathname] = uigetfile( ...
            {'*.IMA;*.ima;*.dcm;*.DCM;IM*', ...
             'DSA DICOM 文件 (*.IMA, *.dcm, IM*)'; ...
             '*.*', '所有文件 (*.*)'}, ...
            '选择一个多帧 DSA DICOM 文件', project_dir);
        if isequal(filename, 0)
            return;
        end
        source_file = fullfile(pathname, filename);
    end

    end
    use_geometry=use_partition||use_imported;
    cache_enabled=cache_options.Enabled&&use_geometry;
    capture_seconds=0;source_identity=[];raw_products=struct();cache_error='';
    if cache_enabled
        capture_started=tic;source_identity=dsap_source_identity(source_file);
        capture_seconds=toc(capture_started);
    end
    % Scientific provenance must exist independently of the optional R1 cache.
    if isempty(source_identity),source_identity=dsap_source_identity(source_file);end
    dsap_task_control('check');
    info = dicominfo(source_file);
    raw = dicomread(source_file);
    dsap_task_control('check');
    sequence = normalize_dicom_sequence(raw, info);
    clear raw;
    detected_frame_rate = detect_frame_rate(info);

    defaults = {num2str(detected_frame_rate, '%.6g'), '0', ...
        num2str(min(5, max(1, size(sequence, 1) - 1)))};
    if is_replay
        answer={num2str(replay.FallbackFrameRate,16), ...
            num2str(replay.ManualDiscardedFrames),num2str(replay.BaselineFrames)};
    elseif dsap_workspace_bridge('active')
        answer=dsap_workspace_bridge('settings',defaults);
    else
    answer = inputdlg( ...
        {'备用帧率（仅无有效 FrameTimeVector 时使用，帧/秒）', ...
         '自动检测前预先丢弃帧数（通常填 0）', ...
         '用于基线估计的帧数'}, ...
        '序列设置', [1 42], defaults);
    end
    if isempty(answer)
        return;
    end

    frame_rate = str2double(answer{1});
    discard_frames = round(str2double(answer{2}));
    baseline_frames = round(str2double(answer{3}));
    validate_sequence_settings(frame_rate, discard_frames, baseline_frames, size(sequence, 1));

    [time_seconds, time_axis_source] = build_acquisition_time_axis( ...
        info, size(sequence, 1), frame_rate);
    sequence = double(sequence(discard_frames + 1:end, :, :));
    time_seconds = time_seconds(discard_frames + 1:end);
    time_seconds = time_seconds - time_seconds(1);
    baseline_frames = min(baseline_frames, size(sequence, 1) - 1);
    baseline = median(sequence(1:baseline_frames, :, :), 1);
    [noise_map,noise_model]=dsap_estimate_baseline_noise(sequence,baseline_frames);

    % Build only the 2-D polarity projections first. Keeping both complete
    % bright and dark 4-D working arrays would consume hundreds of MB.
    % Baseline is constant in time: project first to avoid two full-volume
    % subtraction/clipping temporaries (identical pixel values).
    bright_reference = squeeze(max(max(sequence, [], 1) - baseline, 0));
    dark_reference = squeeze(max(baseline - min(sequence, [], 1), 0));
    if is_replay
        polarity=replay.ContrastPolarity;
        assert(ismember(polarity,{'bright','dark'}),'无效的增强方向。');
    elseif dsap_workspace_bridge('active')
        polarity='dark'; % Verified production default; replay retains its saved choice.
    else
        polarity = choose_contrast_polarity(bright_reference, dark_reference);
    end
    if isempty(polarity)
        return;
    elseif strcmp(polarity, 'bright')
        sequence = max(sequence - baseline, 0);
        reference_image = bright_reference;
    else
        sequence = max(baseline - sequence, 0);
        reference_image = dark_reference;
    end
    clear baseline bright_reference dark_reference;

    dsap_task_control('check');
    sequence_max = max(sequence, [], 'all');
    if ~isfinite(sequence_max) || sequence_max <= 0
        error('预处理后没有可用的造影增强信号。请检查序列或更换血管明暗选项。');
    end
    % Keep the native baseline-subtracted enhancement until the AIF has
    % been selected. The complete sequence is normalized by the AIF peak
    % below; it is no longer independently scaled by its global maximum.
    reference_image = mat2gray(reference_image);
    workspace_roi=dsap_workspace_bridge('active')&&~is_replay;
    vascular_prepared=[];
    if ~is_replay
        vascular_prepared=dsap_prepare_analysis(source_file,size(reference_image),polarity,source_identity);
    end
    if ~is_replay,use_manual=false;end
    if workspace_roi
        if use_imported
            if isfield(ws,'LegacyDraft')
                assert(strcmp(ws.LegacyIdentity.SHA256,source_identity.SHA256), ...
                    'DSAP:LegacySourceChanged','导入后 DICOM 内容发生变化，请重新导入。');
                dsap_validate_legacy_files(ws.LegacyDraft);timeslice_import=ws.LegacyDraft;
            else
                approved=load(fullfile(project_dir,'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat'),'contract');
                timeslice_import=dsap_timeslice_prepare_import(timeslice_entries,source_file,info,timeslice_provenance,approved.contract);
            end
        end
        auto_aif_context=struct('Info',info,'Time',time_seconds,'SourceIdentity',source_identity);
        auto_aif_context.VascularResult=struct('SourceIdentity',source_identity,'Mask',[], ...
            'Network',vascular_prepared.Network,'Available',vascular_prepared.Available,'Reason',vascular_prepared.Reason);
        if ~isempty(vascular_prepared.FullField)
            auto_aif_context.VascularResult.Mask=vascular_prepared.FullField.ArteryMask;
        end
        [aif_mask,cranial_limits,partition,timeslice_import]=dsap_workspace_bridge('roi',sequence,reference_image,timeslice_import,auto_aif_context);
        if ~use_imported&&isfield(partition,'Mode')&&strcmp(partition.Mode,'Freehand')
            use_manual=true;use_partition=false;use_geometry=false;cache_enabled=false;
        end
    end
    while true % Draft-only loop: no DICOM read or baseline repeats.
    aif_label = 'AIF';
    if use_imported
        if ~is_replay && ~workspace_roi
            approved=load(fullfile(project_dir,'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat'),'contract');
            timeslice_import=dsap_timeslice_prepare_import(timeslice_entries,source_file,info,timeslice_provenance,approved.contract);
        end
        if is_replay,assert(isfield(timeslice_import,'Confirmed')&&isequal(timeslice_import.Confirmed,true),'导入 ROI 必须人工确认。');end
        aif_mask=logical(timeslice_import.AIFMask);
        assert(isequal(size(aif_mask),size(reference_image)),'导入 AIF 尺寸不符。');
        aif_curve=mean(sequence(:,aif_mask),2);cancelled=false;
        aif_label=['TIMESlice AIF ' timeslice_import.AIFEntry.roiId];
    elseif workspace_roi
        aif_curve=mean(sequence(:,aif_mask),2);cancelled=false;
    elseif is_replay
        aif_mask=logical(replay.AIFMask);
        assert(isequal(size(aif_mask),[size(sequence,2) size(sequence,3)]),'保存的 AIF 尺寸不一致。');
        aif_curve=mean(sequence(:,aif_mask),2);
        cancelled=false;
    else
        [aif_mask, aif_curve, ~, cancelled] = select_aif_roi(sequence,time_seconds);
    end
    if cancelled
        return;
    end
    if is_replay || workspace_roi
        if is_replay,cranial_limits=replay.CranialLimits;end
        cranial_limit_mask=false(size(aif_mask));
        assert(cranial_limits.UpperRow>=1 && cranial_limits.LowerRow<=size(aif_mask,1) && ...
            cranial_limits.LowerRow>=cranial_limits.UpperRow,'无效的上下限。');
        cranial_limit_mask(cranial_limits.UpperRow:cranial_limits.LowerRow,:)=true;
        cancelled=false;
    else
        [cranial_limit_mask, cranial_limits, cancelled] = ...
            select_cranial_vertical_limits(reference_image, aif_mask);
    end
    if cancelled
        return;
    end

    if use_partition
        if is_replay
            saved=replay.Partition;
            assert(isfield(saved,'Confirmed')&&isequal(saved.Confirmed,true), ...
                '回放分区必须经过人工确认，不能自动确认模板。');
            partition=dsap_partition_from_controls(saved.OuterControlPoints,saved.InnerControlPoints, ...
                size(aif_mask),cranial_limits);
            partition.Confirmed=true;
            if isfield(saved,'TemplateFitBox'),partition.TemplateFitBox=saved.TemplateFitBox;end
        elseif ~workspace_roi
            [partition,cancelled]=dsap_edit_partition(reference_image,cranial_limits);
            if cancelled,return;end
        end
    end
    if ~is_replay && ~workspace_roi
        definition=partition;if use_imported,definition=timeslice_import;end
        [confirmed,draft_action]=dsap_confirm_roi_overview(reference_image,aif_mask,cranial_limits,definition,use_imported);
        if strcmp(draft_action,'draft'),continue;end
        if ~confirmed,return;end
        if use_imported
            dsap_validate_legacy_files(timeslice_import);timeslice_import.Confirmed=true;
        end
    end
    break;
    end
    roi_snapshot=[];
    snapshot_settings=struct('FallbackFrameRate',frame_rate,'ManualDiscardedFrames',discard_frames, ...
        'BaselineFrames',baseline_frames,'ContrastPolarity',polarity);
    if use_partition||use_manual
        roi_snapshot=dsap_build_roi_snapshot(source_identity,aif_mask,cranial_limits, ...
            partition,snapshot_settings,'NativeDSAP');
    elseif use_imported
        roi_snapshot=dsap_build_roi_snapshot(source_identity,aif_mask,cranial_limits, ...
            timeslice_import,snapshot_settings,'LegacyTIMESlice');
    end
    if dsap_workspace_bridge('active') && ~is_replay
        dsap_task_control('check');
        dsap_validate_roi_snapshot(roi_snapshot,dsap_source_identity(source_file));
        dsap_task_control('finish');dsap_task_control('begin');
        dsap_workspace_bridge('confirmed',roi_snapshot);
    end
    if dsap_workspace_bridge('active')
        [prepared_view,ui_prepare_seconds]=dsap_workspace_bridge('prepare',size(aif_mask));
    else
        [prepared_view,ui_prepare_seconds]=dsap_prepare_critical_view(size(aif_mask));
    end
    prepared_cleanup=onCleanup(@() dsap_release_prepared_view(prepared_view)); %#ok<NASGU>
    output_dir=dsap_run_confirmed_analysis(roi_snapshot,@run_scientific_pipeline, ...
        sequence,noise_map,noise_model,aif_curve,aif_mask,aif_label, ...
        reference_image,time_seconds,time_axis_source,baseline_frames,discard_frames,frame_rate, ...
        polarity,source_file,source_folder,filename,input_mode_name,info, ...
        source_identity,project_dir,is_replay,replay,use_partition,use_imported,use_manual, ...
        use_geometry,partition,timeslice_import,cranial_limits,cranial_limit_mask,cache_enabled, ...
        cache_options,capture_seconds,cache_error,raw_products,prepared_view,ui_prepare_seconds,workflow_started,vascular_prepared);
end

function output_dir=run_scientific_pipeline(roi_snapshot, ...
        sequence,noise_map,noise_model,aif_curve,aif_mask,aif_label, ...
        reference_image,time_seconds,time_axis_source,baseline_frames,discard_frames,frame_rate, ...
        polarity,source_file,source_folder,filename,input_mode_name,info, ...
        source_identity,project_dir,is_replay,replay,use_partition,use_imported,use_manual, ...
        use_geometry,partition,timeslice_import,cranial_limits,cranial_limit_mask,cache_enabled, ...
        cache_options,capture_seconds,cache_error,raw_products,prepared_view,ui_prepare_seconds,workflow_started,vascular_prepared)
    scientific_started=tic;
    dsap_workspace_bridge('stage','AIF / Timing');
    output_dir='';
    aif_normalization_peak = max(aif_curve);
    if ~isfinite(aif_normalization_peak) || aif_normalization_peak <= 0
        error('AIF ROI 中没有可用于归一化的造影增强信号。');
    end
    sequence = sequence / aif_normalization_peak;
    noise_map=noise_map / aif_normalization_peak;
    aif_curve = aif_curve / aif_normalization_peak;
    if nnz(aif_mask) < 3 || max(aif_curve) <= 0
        error('AIF ROI 太小或没有有效增强信号，请重新选择。');
    end

    [onset_frame_after_discard, onset_signal, onset_derivative, ...
        onset_threshold] = detect_aif_onset(aif_curve, baseline_frames);
    sequence = sequence(onset_frame_after_discard:end, :, :);
    time_seconds = time_seconds(onset_frame_after_discard:end);
    time_seconds = time_seconds - time_seconds(1);
    effective_discarded_frames = discard_frames + onset_frame_after_discard - 1;
    aif_curve = mean(sequence(:, aif_mask), 2);
    [~, aif_frame] = max(aif_curve);

    % Preserve the onset-cropped enhancement sequence for pre-resampling
    % TIC export. Native DICOM grayscale curves are kept separately.
    original_tic_sequence = single(sequence);
    original_time_seconds = time_seconds;
    original_aif_curve = mean(original_tic_sequence(:, aif_mask), 2);
    [sequence, time_seconds, temporal_resolution] = ...
        resample_sequence_to_uniform_time(sequence, original_time_seconds);

    % Review pixelwise detectability before TSVD, using the uniformly
    % sampled, centered-filtered sequence. No anatomical brain contour.
    segmentation_sequence = centered_temporal_gaussian_filter( ...
        single(sequence), temporal_resolution);
    dsap_workspace_bridge('stage','Signal Quality');
    if use_imported
        initial_stats=dsap_imported_statistics(timeslice_import,cranial_limit_mask,false(size(aif_mask)), ...
            aif_mask,true(size(aif_mask)),false(size(aif_mask)));
        brain_mask=initial_stats.OuterMask;
        [~,brain_model,brain_features]=dsap_classify_signal_quality( ...
            segmentation_sequence,noise_map,cranial_limit_mask,0,reference_image,brain_mask);
        brain_model.Method='TIMESlice-current-confirmed-ROI-with-advisory-signal-quality';cancelled=false;
    elseif use_partition
        [~,brain_model,brain_features]=dsap_classify_signal_quality( ...
            segmentation_sequence,noise_map,cranial_limit_mask,0,reference_image,partition.OuterMask);
        brain_mask=partition.OuterMask;
        cancelled=false;
    elseif is_replay || use_manual
        [brain_mask,brain_model,brain_features]=dsap_classify_signal_quality( ...
            segmentation_sequence,noise_map,cranial_limit_mask,0,reference_image);
        cancelled=false;
    else
        [brain_mask, brain_model, brain_features, cancelled] = ...
            review_signal_quality(reference_image,aif_mask,cranial_limit_mask, ...
            cranial_limits,segmentation_sequence,noise_map);
    end
    brain_model.NoiseEstimation=noise_model;
    clear segmentation_sequence;
    if cancelled
        return;
    end

    % CAVE reads the complete native DICOM independently. Its 1 fps input
    % must never replace the onset-cropped perfusion sequence/time axis.
    dsap_workspace_bridge('stage','CAVE');
    [large_vessel_mask,capillary_mask,vessel_model,vessel_features,full_cave]= ...
        segment_large_vessels_cave(source_file,aif_mask,brain_mask, ...
        brain_features.ProjectionForegroundMask,cranial_limits,polarity,'ShowProgress',~is_replay&&~dsap_workspace_bridge('active'),'Prepared',vascular_prepared);
    if is_replay
        added=false(size(aif_mask));restored=added;
        if isfield(replay,'CAVEManualAddedMask'),added=replay.CAVEManualAddedMask;end
        if isfield(replay,'CAVEManualRestoredMask'),restored=replay.CAVEManualRestoredMask;end
        [large_vessel_mask,capillary_mask,vessel_model,vessel_features]= ...
            dsap_apply_cave_corrections(vessel_model,vessel_features,added,restored, ...
            brain_features.ProjectionForegroundMask,brain_mask,aif_mask);
        cancelled=false;
    elseif cache_options.Enabled
        [large_vessel_mask,capillary_mask,vessel_model,vessel_features,cancelled]= ...
            review_cave_vessel_mask(reference_image,aif_mask,brain_mask, ...
            brain_features.ProjectionForegroundMask,cranial_limits,vessel_model,vessel_features);
    else
        [large_vessel_mask,capillary_mask,vessel_model,vessel_features,cancelled,cave_production_qc]= ...
            dsap_cave_production_review(reference_image,aif_mask,brain_mask, ...
            brain_features.ProjectionForegroundMask,vessel_model,vessel_features);
    end
    if cancelled
        return;
    end

    whole_brain_mask = capillary_mask & ~aif_mask;
    if nnz(whole_brain_mask) < 3
        error('有效显影组织少于 3 个像素，请检查噪声估计、识别阈值和大血管排除。');
    end
    roi_names = {'有效显影组织'};
    roi_masks = {whole_brain_mask};
    roi_frames = NaN;

    roi_types = {'AutomaticSignalValidTissue'};
    roi_merge_sources = {''};
    if use_partition
        roi_names={'皮层';'皮层下';'颅内合并'};
        roi_frames=nan(3,1);roi_types={'ManualPartitionCortex';'ManualPartitionSubcortex';'Merged'};
        roi_merge_sources={'';'';'皮层 + 皮层下'};
    elseif use_manual
        roi_names=partition.Names(:);roi_frames=partition.SelectedFrames(:);
        roi_types=partition.Types(:);roi_merge_sources=partition.MergeSources(:);
    end

    progress = dsap_progress(0.15, '正在进行 TSVD 反卷积...', 'DSA 灌注分析');
    cleanup_progress = onCleanup(@() close_if_valid(progress));
    [CBF, CBV, Tmax, MTT, tics, irfs] = modelfree_deconvolution_corrected( ...
        sequence, aif_mask, 'dt', temporal_resolution, 'prefilter', 1);
    clear sequence;
    vessel_parameter_maps={CBF,CBV,Tmax,MTT}; % preserve before tissue-specific postprocessing
    if cache_enabled,raw_products.ParameterMaps=vessel_parameter_maps;end
    aif_curve = mean(tics(:, aif_mask), 2);
    numerical_valid=isfinite(CBF)&isfinite(CBV)&isfinite(Tmax)&isfinite(MTT)&CBF>0&CBV>0;
    dsap_task_control('check');
    if isgraphics(progress),waitbar(0.75, progress, '正在后处理参数图...');end
    dsap_workspace_bridge('stage','Post-processing');
    numerical_scope=true(size(CBF));
    if use_geometry,numerical_scope=capillary_mask;end
    [CBF, CBV, Tmax, MTT] = postprocess_maps(CBF, CBV, Tmax, MTT,numerical_scope);
    numerical_valid=numerical_valid & CBF>max(CBF(numerical_scope),[],'all')*1e-4;
    inclusive_parameter_maps={CBF,CBV,Tmax,MTT}; % Same processed fit, before any vessel/tissue display masking.
    brain_features.NumericallyUnreliableMask=capillary_mask & ~numerical_valid;
    capillary_mask=capillary_mask & numerical_valid;
    whole_brain_mask=capillary_mask;
    roi_masks={whole_brain_mask};
    irf_masks=roi_masks;
    dsap_workspace_bridge('stage','ROI Statistics');
    if use_imported
        partition_stats=dsap_roi_snapshot_statistics(roi_snapshot,large_vessel_mask, ...
            aif_mask,numerical_valid,brain_features.NonfiniteInputMask);
        roi_masks=partition_stats.TICMasks;irf_masks=partition_stats.ParameterMasks;
        roi_names=partition_stats.Names;roi_frames=nan(numel(roi_names),1);
        roi_types=repmat({'TIMESliceCurrentROI'},numel(roi_names),1);roi_merge_sources=repmat({''},numel(roi_names),1);
        if numel(timeslice_import.Masks)>1
            roi_types{end}='Merged';roi_merge_sources{end}=strjoin(timeslice_import.Names,' + ');
        end
        whole_brain_mask=false(size(aif_mask));
        for k=1:numel(irf_masks),whole_brain_mask=whole_brain_mask|irf_masks{k};end
        capillary_mask=whole_brain_mask;
    elseif use_partition
        partition_stats=dsap_roi_snapshot_statistics(roi_snapshot,large_vessel_mask,aif_mask, ...
            numerical_valid,brain_features.NonfiniteInputMask);
        roi_masks=partition_stats.TICMasks;irf_masks=partition_stats.ParameterMasks;
        whole_brain_mask=irf_masks{3};capillary_mask=whole_brain_mask;
    elseif use_manual
        % Historical freehand rule: createMask(roi) intersected with the
        % valid capillary tissue after CAVE and numerical postprocessing.
        selected_rois=roi_snapshot.ROIs(ismember({roi_snapshot.ROIs.ID},roi_snapshot.StatisticsPlan.ROIIds));
        roi_masks=cell(numel(selected_rois),1);whole_brain_mask=false(size(aif_mask));
        for index=1:numel(selected_rois)
            roi_masks{index}=selected_rois(index).Mask & capillary_mask;
            assert(nnz(roi_masks{index})>=3, ...
                '手绘 ROI %s 排除血管和无效组织后不足 3 个像素。',selected_rois(index).Name);
            whole_brain_mask=whole_brain_mask|roi_masks{index};
        end
        irf_masks=roi_masks;capillary_mask=whole_brain_mask;
    elseif nnz(whole_brain_mask)<3
        error('可可靠计算的组织像素不足 3 个。');
    end
    brain_features.FinalTissueMask=whole_brain_mask;
    brain_model.FinalTissuePixelCount=nnz(whole_brain_mask);
    brain_model.NumericallyUnreliablePixelCount=nnz(brain_features.NumericallyUnreliableMask);
    vessel_roi_results=dsap_cave_vessel_rois(vessel_features,large_vessel_mask, ...
        brain_features.NonfiniteInputMask,aif_mask);
    tissue_roi_count=numel(roi_masks);
    [native_original_aif_curve, all_native_tics, native_capture] = ...
        extract_native_dicom_curves(source_file, info, discard_frames, ...
        onset_frame_after_discard, aif_mask, [roi_masks(:);vessel_roi_results.Masks(:)],cache_enabled);
    native_original_roi_tics=all_native_tics(1:tissue_roi_count);
    vessel_roi_results.NativeTIC=all_native_tics(tissue_roi_count+1:end);
    clear all_native_tics;

    volume_map = squeeze(trapz(time_seconds, tics, 1));
    [peak_map, ttp_index] = max(tics, [], 1);
    peak_map = squeeze(peak_map);
    ttp_map = reshape(time_seconds(ttp_index(:)), size(ttp_index));
    ttp_map = squeeze(ttp_map);
    intensity_map = squeeze(mean(tics, 1));
    if cache_enabled
        raw_products.Descriptors={volume_map,peak_map,ttp_map,intensity_map};
    end
    vessel_roi_results=calculate_vessel_roi_results(vessel_roi_results,vessel_parameter_maps, ...
        tics,irfs,original_tic_sequence,time_seconds,volume_map,peak_map,ttp_map,intensity_map);
    clear vessel_parameter_maps;
    if use_geometry
        % TIC descriptors use every finite non-vessel pixel, even when its
        % deconvolution is unreliable. Perfusion maps use valid fits only.
        tic_union=false(size(aif_mask));for k=1:numel(roi_masks),tic_union=tic_union|roi_masks{k};end
        outside=~tic_union;
        volume_map(outside)=NaN;peak_map(outside)=NaN;ttp_map(outside)=NaN;intensity_map(outside)=NaN;
        CBF(~capillary_mask)=NaN;CBV(~capillary_mask)=NaN;Tmax(~capillary_mask)=NaN;MTT(~capillary_mask)=NaN;
    else
    [CBF, CBV, Tmax, MTT, volume_map, peak_map, ttp_map, intensity_map] = ...
        apply_capillary_mask(capillary_mask, CBF, CBV, Tmax, MTT, ...
        volume_map, peak_map, ttp_map, intensity_map);
    end

    [roi_tics, roi_irfs, original_roi_tics] = extract_roi_curves( ...
        roi_masks, tics, irfs, original_tic_sequence,irf_masks);

    summary_table = build_summary_table(roi_names, roi_masks, roi_frames, ...
        roi_types, roi_merge_sources, CBF, CBV, ...
        Tmax, MTT, volume_map, peak_map, ttp_map, intensity_map, ...
        roi_irfs, time_seconds);
    if use_geometry
        summary_table=[summary_table partition_stats.Coverage(:,2:end)];
    end
    vessel_summary=vessel_roi_results.Summary;
    if use_geometry
        vessel_summary=[vessel_summary vessel_roi_results.Coverage(:,2:end)];
    end
    summary_table=[summary_table;vessel_summary];
    roi_names=[roi_names(:);vessel_roi_results.Names];
    roi_types=[roi_types(:);vessel_roi_results.Types];roi_merge_sources=[roi_merge_sources(:);{'';''}];
    roi_frames=[roi_frames(:);NaN;NaN];roi_masks=[roi_masks(:);vessel_roi_results.Masks];
    roi_tics=[roi_tics(:);vessel_roi_results.TIC];roi_irfs=[roi_irfs(:);vessel_roi_results.IRF];
    original_roi_tics=[original_roi_tics(:);vessel_roi_results.OriginalTIC];
    native_original_roi_tics=[native_original_roi_tics(:);vessel_roi_results.NativeTIC];
    scientific_compute_seconds=toc(scientific_started);
    dsap_workspace_bridge('stage','Rendering Results');
    presentation_started=tic;
    setappdata(groot,'DSAPResultReadyClock',presentation_started); % Scientific calculation has finished, before capture.
    cache=[];cache_inputs=struct();
    if cache_enabled
        capture_started=tic;
        checked_source=dsap_source_identity(source_file);
        assert(strcmp(source_identity.SHA256,checked_source.SHA256),'DSAP:SourceChanged','分析期间 DICOM 内容改变。');
        cache_inputs=struct('filtered',tics,'irf',irfs,'enhanced',original_tic_sequence,'native',native_capture);
        % Reserve covers retained maps/results/features in addition to the packed volumes.
        try
            cache=dsap_session_cache('plan',cache_inputs,brain_mask,cache_options,192*1024^2);
            if strcmp(cache.Mode,'ram')
                cache=dsap_session_cache('build',cache,cache_inputs);
                cache_inputs=struct();
            end
        catch cache_exception
            cache_error=cache_exception.message;cache_enabled=false;cache=[];cache_inputs=struct();
            warning('DSAP:CacheUnavailable','结果仍会显示和保存；编辑缓存不可用：%s',cache_error);
        end
        capture_seconds=capture_seconds+toc(capture_started);
    end
    close_if_valid(progress);
    clear cleanup_progress;

    settings = struct( ...
        'InputMode', input_mode_name, ...
        'SourceFolder', source_folder, ...
        'FrameRate', 1 / temporal_resolution, ...
        'FallbackFrameRate', frame_rate, ...
        'TimeAxisSource', time_axis_source, ...
        'DiscardedFrames', effective_discarded_frames, ...
        'ManualDiscardedFrames', discard_frames, ...
        'AutoOnsetFrameAfterManualDiscard', onset_frame_after_discard, ...
        'AutoOnsetThreshold', onset_threshold, ...
        'AutoOnsetSignal', onset_signal, ...
        'AutoOnsetDerivative', onset_derivative, ...
        'AIFLabel', aif_label, ...
        'BaselineFrames', baseline_frames, ...
        'AIFNormalizationPeakNative', aif_normalization_peak, ...
        'AIFNormalizationPeakBaselineCorrected', aif_normalization_peak, ...
        'NormalizationMethod', 'baseline-corrected tissue enhancement / AIF peak', ...
        'AIFFrame', aif_frame, ...
        'ContrastPolarity', polarity, ...
        'TemporalResolutionSeconds', temporal_resolution, ...
        'OriginalTimeSeconds', original_time_seconds, ...
        'ResampledTimeSeconds', time_seconds, ...
        'TemporalResampling', 'linear', ...
        'TemporalFilter', 'centered Gaussian with replicated endpoints', ...
        'TmaxTimeAxis', 'zero-based', ...
        'FullTemporalVolumesSaved', false, ...
        'NativeRawTICDefinition', 'mean native DICOM grayscale after frame cropping', ...
        'ManualCranialLimits', cranial_limits, ...
        'SignalIdentification', brain_model.Method, ...
        'SignalIdentificationModel', brain_model, ...
        'AnalysisRegionDefinition', 'MIP bright foreground within selected limits, with sustained enhancement, minus vessels/AIF and invalid fits', ...
        'AnatomicalWholeBrain', false, ...
        'ExcludedParameterValue','NaN (not zero perfusion)', ...
        'ProjectionLimitation', ['2-D DSA cannot separate intracranial and ', ...
            'extracranial structures that overlap along the same x-ray path'], ...
        'LargeVesselRemoval', vessel_model.Method, ...
        'LargeVesselModel', vessel_model, ...
        'CapillaryCBVThreshold', NaN);
    if use_partition
        settings.AnalysisRegionDefinition='confirmed outer/inner geometric masks minus large vessels and AIF';
        settings.PartitionMethod=partition.Method;
        settings.TICScope='all finite non-vessel non-AIF pixels in confirmed masks; no MIP/SNR exclusion';
        settings.PerfusionScope='numerically valid fits only; excluded fits are NaN, coverage saved separately';
        settings.IRFScope='same numerically valid pixels as perfusion parameters';
        settings.NumericalFloorScope='non-vessel pixels inside confirmed outer mask';
    end

    if use_imported
        settings.InputMode='TIMESlice-current-ROI-and-AIF';
        settings.AnalysisRegionDefinition='confirmed TIMESlice current ROI masks clipped to cranial limits minus CAVE and AIF';
        settings.TimesliceProvenance=timeslice_import.Provenance;
        settings.TICScope='all finite non-vessel non-AIF ROI pixels; no MIP/SNR exclusion';
        settings.PerfusionScope='numerically valid fits only; coverage saved separately';
    end
    if use_manual
        settings.AnalysisRegionDefinition='legacy freehand logical mask intersected with valid capillary tissue after CAVE';
        settings.TissueROIDrawing='drawfreehand/createMask(roi)';
    end
    settings.VesselROIReporting=vessel_roi_results.Definition;
    settings.VesselROIOverlapPolicy=vessel_roi_results.OverlapPolicy;
    settings.VesselROIParameterInterpretation=vessel_roi_results.ParameterInterpretation;
    settings.TissueROICount=tissue_roi_count;
    dsap_task_control('check');
    output_dir = make_output_directory(project_dir, filename);
    result=struct();
    result.source_file=source_file;
    result.source_identity=source_identity;
    result.cave_full_field=full_cave;
    result.analysis_revision=struct('SessionId',char(java.util.UUID.randomUUID()),'Revision',0,'SourceSHA256',source_identity.SHA256);
    if exist('cave_production_qc','var'),result.cave_production_qc=cave_production_qc;end
    if ~isempty(roi_snapshot),result.roi_snapshot=roi_snapshot;end
    result.info=info;
    result.settings=settings;
    result.reference_image=reference_image;
    result.aif_mask=aif_mask;
    result.cranial_limit_mask=cranial_limit_mask;
    result.cranial_limits=cranial_limits;
    result.brain_mask=brain_mask;
    result.large_vessel_mask=large_vessel_mask;
    result.capillary_mask=capillary_mask;
    result.vessel_model=vessel_model;
    result.vessel_features=vessel_features;
    result.aif_curve=aif_curve;
    result.original_aif_curve=original_aif_curve;
    result.native_original_aif_curve=native_original_aif_curve;
    result.aif_frame=aif_frame;
    result.roi_names=roi_names;
    result.roi_masks=roi_masks;
    result.roi_types=roi_types;
    result.roi_merge_sources=roi_merge_sources;
    result.roi_tics=roi_tics;
    result.original_roi_tics=original_roi_tics;
    result.native_original_roi_tics=native_original_roi_tics;
    result.roi_irfs=roi_irfs;
    result.roi_frames=roi_frames;
    result.original_time_seconds=original_time_seconds;
    result.time_seconds=time_seconds;
    result.summary_table=summary_table;
    result.CBF=CBF;
    result.CBV=CBV;
    result.Tmax=Tmax;
    result.MTT=MTT;
    result.volume_map=volume_map;
    result.peak_map=peak_map;
    result.ttp_map=ttp_map;
    result.intensity_map=intensity_map;
    result.vessel_roi_results=vessel_roi_results;
    result.signal_valid_mask=brain_features.SignalValidMask;
    result.valid_tissue_mask=whole_brain_mask;
    result.signal_quality_model=brain_model;
    result.signal_quality_features=brain_features;
    if ~isempty(roi_snapshot)
        dsap_validate_roi_snapshot(roi_snapshot,dsap_source_identity(source_file));
    end
    if use_partition,result.partition=partition;result.partition_stats=partition_stats;end
    if use_manual,result.manual_tissue=partition;end
    if use_imported,result.timeslice_import=timeslice_import;result.partition_stats=partition_stats;end
    result=dsap_vessel_inclusive_analysis(result,inclusive_parameter_maps,numerical_valid);
    clear inclusive_parameter_maps;
    result=dsap_attach_roi_distribution(result); % Downstream of finalized maps and frozen ROI only.
    result=dsap_roi_artery_analysis(result);
    owner=dsap_result_owner('create',result,output_dir);
    dsap_result_owner('attach',owner,prepared_view);
    pre_show_seconds=toc(presentation_started);
    [result_view,presentation_timing]=dsap_show_results(result,output_dir,prepared_view,get(groot,'DefaultFigureVisible'),owner);
    presentation_timing.CriticalVisibleSeconds=presentation_timing.CriticalVisibleSeconds+pre_show_seconds;
    presentation_timing.UIPrepareSeconds=ui_prepare_seconds;
    presentation_timing.ScientificComputeSeconds=scientific_compute_seconds;
    dsap_result_owner('attach',owner,result_view);
    presentation_timing.CalculationToAllResultsPreparedSeconds=toc(presentation_started);
    presentation_timing.CalculationToAllResultsVisibleSeconds=NaN;
    if strcmp(presentation_timing.Visibility,'on')
        presentation_timing.CalculationToAllResultsVisibleSeconds=toc(presentation_started);
    end
    result.presentation_timing=presentation_timing;
    if cache_enabled
        result.source_identity=source_identity;
        result.cave_full_field=full_cave;
        result.analysis_revision=struct('SessionId',cache.Id,'Revision',0,'SourceSHA256',source_identity.SHA256);
        if strcmp(cache.Mode,'disk')
            controls=getappdata(result_view.Table,'DSAPResultControls');
            controls.Status.String='结果已显示；正在建立有界磁盘编辑缓存…';drawnow;
            capture_started=tic;
            try,cache=dsap_session_cache('build',cache,cache_inputs);
            catch cache_exception
                cache_error=cache_exception.message;cache_enabled=false;cache=[];
                warning('DSAP:CacheUnavailable','结果仍会保存；编辑缓存不可用：%s',cache_error);
            end
            capture_seconds=capture_seconds+toc(capture_started);cache_inputs=struct();
        end
    end
    cache_cleanup=onCleanup(@() dsap_release_unowned_cache(cache)); %#ok<NASGU>
    dsap_result_owner('update',owner,result);
    save_started=tic;
    [saved,save_error]=dsap_result_owner('save',owner);
    core_save_seconds=toc(save_started);
    runtime_variables=whos('tics','irfs','original_tic_sequence','native_capture');
    runtime_bytes_before=sum([runtime_variables.bytes]);
    process=System.Diagnostics.Process.GetCurrentProcess();process.Refresh();working_set_before=double(process.WorkingSet64);
    clear tics irfs original_tic_sequence native_capture;
    runtime_variables_after=whos('tics','irfs','original_tic_sequence','native_capture');
    process.Refresh();working_set_after=double(process.WorkingSet64);
    if ~saved
        warning('DSAP:CoreSaveFailed','完整结果及 Snapshot 已保留，可在结果窗口重试保存：%s',save_error);
        return;
    end
    if cache_enabled&&isgraphics(result_view.Table)
        session_started=tic;
        session=dsap_start_analysis_session(result,source_identity,cache,numerical_valid,raw_products,full_cave,result_view,output_dir);
        capture_seconds=capture_seconds+toc(session_started);
    end
    session_metrics=struct('CacheEnabled',cache_enabled,'CaptureSeconds',capture_seconds, ...
        'CoreSaveSeconds',core_save_seconds,'Presentation',presentation_timing,'CacheError',cache_error);
    if cache_enabled
        session_metrics.CacheMode=cache.Mode;session_metrics.CachePayloadBytes=cache.PayloadBytes;
        session_metrics.PayloadCaptureSeconds=cache.CaptureSeconds;
    end
    session_metrics.UIPrepareSeconds=ui_prepare_seconds;
    session_metrics.ScientificComputeSeconds=scientific_compute_seconds;
    session_metrics.CriticalVisibleSeconds=presentation_timing.CriticalVisibleSeconds;
    session_metrics.AuxiliaryCompleteSeconds=presentation_timing.CalculationToAllResultsPreparedSeconds;
    session_metrics.TotalWorkflowWallSeconds=toc(workflow_started);
    session_metrics.RuntimeVolumeBytesBeforeRelease=runtime_bytes_before;
    session_metrics.RuntimeVolumeBytesAfterRelease=sum([runtime_variables_after.bytes]);
    session_metrics.WorkingSetBeforeRelease=working_set_before;
    session_metrics.WorkingSetAfterRelease=working_set_after;
    setappdata(groot,'DSAPLastSessionMetrics',session_metrics);
    if ~isempty(cache_error)&&isgraphics(result_view.Table)
        controls=getappdata(result_view.Table,'DSAPResultControls');
        controls.Status.String=['核心结果已保存；编辑缓存未建立：' cache_error];drawnow;
    end
    fprintf('结果呈现 %.3f s；核心保存 %.3f s；完整图像/报告请在结果窗口主动导出。\n', ...
        presentation_timing.CalculationToAllResultsPreparedSeconds,toc(save_started));
    disp(' ');
    disp('ROI 灌注参数：');
    disp(summary_table);
    fprintf('结果已保存到：%s\n', output_dir);
    if ~is_replay && ~dsap_workspace_bridge('active')
    msgbox(sprintf('分析完成，核心科研结果已保存。\n完整图像 / 报告可在结果窗口主动导出。\n\n结果目录：\n%s', output_dir), ...
        'DSA 灌注分析', 'help');
    end
end

function [source_file, folder_path, cancelled] = select_dicom_from_folder(project_dir)
    source_file = '';
    folder_path = uigetdir(project_dir, '选择包含多个 DSA 序列的文件夹');
    cancelled = isequal(folder_path, 0);
    if cancelled
        folder_path = '';
        return;
    end

    progress = dsap_progress(0, '正在扫描 DICOM 文件夹...', '导入 DICOM 文件夹');
    cleanup_progress = onCleanup(@() close_if_valid(progress));
    [candidates, stats] = scan_dicom_folder_sequences(folder_path, ...
        @(fraction, message) update_scan_progress(progress, fraction, message));
    close_if_valid(progress);
    clear cleanup_progress;

    if isempty(candidates)
        error(['所选文件夹中没有找到至少包含 3 帧的灰度多帧 DSA 序列。', ...
            '已扫描 %d 个文件，其中 DICOM 文件 %d 个。'], ...
            stats.ScannedFileCount, stats.DicomFileCount);
    end
    [source_file, cancelled] = browse_dicom_folder_candidates( ...
        candidates, folder_path, stats);
end

function update_scan_progress(progress, fraction, message)
    dsap_task_control('check');
    if isgraphics(progress)
        waitbar(min(max(fraction, 0), 1), progress, message);
        drawnow limitrate;
    end
end

function [source_file, cancelled] = browse_dicom_folder_candidates( ...
        candidates, folder_path, stats)
    source_file = '';
    cancelled = true;
    candidate_count = numel(candidates);
    column_count = min(6, max(3, ceil(sqrt(candidate_count * 1.8))));
    row_count = ceil(candidate_count / column_count);

    browser = figure('Name', '选择 DSA 影像序列', 'NumberTitle', 'off', ...
        'Color', [0.96 0.96 0.96], 'Position', [25 40 1500 900], ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Visible', 'off');
    browser.CloseRequestFcn = @(source, ~) close_series_browser(source);
    layout = tiledlayout(browser, row_count, column_count, ...
        'Padding', 'compact', 'TileSpacing', 'compact');
    layout.Units = 'normalized';
    layout.Position = [0.015 0.13 0.97 0.83];

    axes_handles = gobjects(candidate_count, 1);
    title_handles = gobjects(candidate_count, 1);
    for index = 1:candidate_count
        ax = nexttile(layout);
        axes_handles(index) = ax;
        image_handle = imshow(candidates(index).Thumbnail, [], 'Parent', ax);
        axis(ax, 'image');
        ax.XTick = [];
        ax.YTick = [];
        ax.Box = 'on';
        ax.LineWidth = 1;
        ax.XColor = [0.65 0.65 0.65];
        ax.YColor = [0.65 0.65 0.65];
        label = {sprintf('[%02d] Series %s | %s', index, ...
            candidates(index).SeriesNumberText, candidates(index).Plane), ...
            sprintf('%s | %d 帧 | %.2f s', candidates(index).Description, ...
            candidates(index).FrameCount, candidates(index).DurationSeconds), ...
            candidates(index).RelativePath};
        title_handles(index) = title(ax, label, 'FontSize', 8, ...
            'FontWeight', 'normal', 'Interpreter', 'none');
        image_handle.ButtonDownFcn = @(~, ~) ...
            folder_thumbnail_clicked(browser, index);
        ax.ButtonDownFcn = @(~, ~) folder_thumbnail_clicked(browser, index);
    end

    status = uicontrol(browser, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.065 0.60 0.05], 'BackgroundColor', browser.Color, ...
        'HorizontalAlignment', 'left', 'FontSize', 10, 'String', '');
    summary_text = sprintf(['文件夹：%s\n找到 %d 个多帧序列；', ...
        '已隐藏 %d 个单帧影像。单击缩略图选择，双击可动态预览。'], ...
        folder_path, candidate_count, stats.SingleFrameCount);
    uicontrol(browser, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.005 0.60 0.055], 'BackgroundColor', browser.Color, ...
        'HorizontalAlignment', 'left', 'FontSize', 9, ...
        'String', summary_text);
    uicontrol(browser, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.66 0.035 0.10 0.055], 'String', '动态预览', ...
        'FontSize', 10, 'Callback', @(~, ~) ...
        preview_selected_folder_candidate(browser));
    uicontrol(browser, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.78 0.035 0.11 0.055], 'String', '使用选中序列', ...
        'FontSize', 10, 'FontWeight', 'bold', 'Callback', @(~, ~) ...
        finish_series_browser(browser, 'use'));
    uicontrol(browser, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.91 0.035 0.07 0.055], 'String', '取消', ...
        'FontSize', 10, 'Callback', @(~, ~) ...
        finish_series_browser(browser, 'cancel'));

    setappdata(browser, 'Candidates', candidates);
    setappdata(browser, 'SelectedIndex', 1);
    setappdata(browser, 'BrowserAction', '');
    setappdata(browser, 'AxesHandles', axes_handles);
    setappdata(browser, 'TitleHandles', title_handles);
    setappdata(browser, 'StatusHandle', status);
    setappdata(browser, 'PreviewFigure', gobjects(0));
    select_folder_candidate(browser, 1);
    browser.Visible = 'on';
    figure(browser);
    drawnow;
    if isgraphics(browser) && isempty(getappdata(browser,'BrowserAction'))
        uiwait(browser);
    end

    if ~isgraphics(browser)
        return;
    end
    action = getappdata(browser, 'BrowserAction');
    selected_index = getappdata(browser, 'SelectedIndex');
    if strcmp(action, 'use')
        source_file = candidates(selected_index).FilePath;
        cancelled = false;
    end
    browser.CloseRequestFcn = '';
    delete(browser);
end

function folder_thumbnail_clicked(browser, index)
    if ~isgraphics(browser)
        return;
    end
    select_folder_candidate(browser, index);
    if strcmp(browser.SelectionType, 'open')
        preview_selected_folder_candidate(browser);
    end
end

function select_folder_candidate(browser, index)
    candidates = getappdata(browser, 'Candidates');
    axes_handles = getappdata(browser, 'AxesHandles');
    title_handles = getappdata(browser, 'TitleHandles');
    index = min(max(round(index), 1), numel(candidates));
    setappdata(browser, 'SelectedIndex', index);

    for candidate_index = 1:numel(candidates)
        axes_handles(candidate_index).LineWidth = 1;
        axes_handles(candidate_index).XColor = [0.65 0.65 0.65];
        axes_handles(candidate_index).YColor = [0.65 0.65 0.65];
        title_handles(candidate_index).Color = [0.15 0.15 0.15];
        title_handles(candidate_index).FontWeight = 'normal';
    end
    axes_handles(index).LineWidth = 3;
    axes_handles(index).XColor = [0.00 0.45 0.74];
    axes_handles(index).YColor = [0.00 0.45 0.74];
    title_handles(index).Color = [0.00 0.32 0.65];
    title_handles(index).FontWeight = 'bold';

    selected = candidates(index);
    status = getappdata(browser, 'StatusHandle');
    status.String = sprintf(['当前选择：[%02d] %s | Series %s | %s | ', ...
        '%d 帧 | %dx%d | %.2f s'], index, selected.FileName, ...
        selected.SeriesNumberText, selected.Plane, selected.FrameCount, ...
        selected.Rows, selected.Columns, selected.DurationSeconds);
end

function preview_selected_folder_candidate(browser)
    if ~isgraphics(browser)
        return;
    end
    if isequal(getappdata(browser,'PreviewLoading'),true),return;end
    setappdata(browser,'PreviewLoading',true);
    cleanup_loading=onCleanup(@() clear_preview_loading(browser)); %#ok<NASGU>
    candidates = getappdata(browser, 'Candidates');
    selected_index = getappdata(browser, 'SelectedIndex');
    preview = getappdata(browser, 'PreviewFigure');
    if ~isempty(preview) && isgraphics(preview)
        figure(preview);
        return;
    end
    browser.Visible = 'off';
    try
        show_dicom_cine_preview(candidates(selected_index), browser);
    catch ME
        if strcmp(ME.identifier,'DSAP:Cancelled') || dsap_task_control('cancelled'),return;end
        if isgraphics(browser)
            browser.Visible = 'on';
            figure(browser);
        end
        errordlg(ME.message, '动态预览加载失败');
    end
end

function clear_preview_loading(browser)
    if isgraphics(browser),setappdata(browser,'PreviewLoading',false);end
end

function show_dicom_cine_preview(candidate, browser)
    file_state = dir(candidate.FilePath);
    preview_key = {candidate.FilePath, [file_state.bytes], [file_state.datenum]};
    cached_preview = getappdata(browser, 'CachedPreview');
    if ~isempty(cached_preview) && isequal(cached_preview.Key, preview_key)
        display_sequence = cached_preview.Sequence;
        frame_signal = cached_preview.Signal;
        preview_time = cached_preview.Time;
    else
        % Keep at most one display sequence, never the raw double volume.
        if isappdata(browser, 'CachedPreview')
            rmappdata(browser, 'CachedPreview');
        end
        clear cached_preview;
        progress = dsap_progress(0.1, sprintf('正在加载 %s...', candidate.FileName), 'DSA 动态预览');
        cleanup_progress = onCleanup(@() close_if_valid(progress));
        raw = dicomread(candidate.FilePath);
        dsap_task_control('check');
        source_sequence = normalize_dicom_sequence(raw, candidate.Info);
        waitbar(0.65, progress, '正在准备动态预览...');
        display_sequence = scale_sequence_for_preview(source_sequence);
        frame_signal = compute_preview_frame_signal(source_sequence);
        [preview_time, ~] = build_acquisition_time_axis(candidate.Info, ...
            size(source_sequence, 1), detect_frame_rate(candidate.Info));
        clear raw source_sequence;
        close_if_valid(progress);
        clear cleanup_progress;
        if numel(display_sequence) <= 128 * 1024^2
            setappdata(browser, 'CachedPreview', struct('Key', {preview_key}, ...
                'Sequence', display_sequence, 'Signal', frame_signal, 'Time', preview_time));
        end
    end

    instruction = sprintf('%s | Series %s | %s', candidate.FileName, ...
        candidate.SeriesNumberText, candidate.Plane);
    viewer = create_sequence_viewer(display_sequence, 'DSA 动态序列预览', ...
        instruction);
    set_viewer_frame(viewer.Figure, candidate.PreviewFrame);
    plot(viewer.CurveAxes, preview_time, frame_signal, 'b-', 'LineWidth', 1.5);
    grid(viewer.CurveAxes, 'on');
    xlabel(viewer.CurveAxes, '真实时间 (s)');
    ylabel(viewer.CurveAxes, '相对帧变化');
    title(viewer.CurveAxes, '序列增强变化概览');

    play_button = uicontrol(viewer.Figure, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.61 0.01 0.10 0.05], ...
        'String', '播放', 'FontSize', 10, ...
        'Callback', @(source, ~) toggle_cine_playback(viewer.Figure, source));
    uicontrol(viewer.Figure, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.74 0.01 0.11 0.05], ...
        'String', '使用此序列', 'FontSize', 10, 'FontWeight', 'bold', ...
        'Callback', @(~, ~) dsap_finish_cine_preview( ...
        viewer.Figure, 'use', browser));
    uicontrol(viewer.Figure, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.88 0.01 0.08 0.05], ...
        'String', '返回总览', 'FontSize', 10, ...
        'Callback', @(~, ~) dsap_finish_cine_preview( ...
        viewer.Figure, 'back', browser));
    setappdata(viewer.Figure, 'PreviewAction', '');
    setappdata(viewer.Figure, 'PreviewPlaying', false);
    setappdata(viewer.Figure, 'PreviewTime', preview_time);
    setappdata(viewer.Figure, 'PlayButton', play_button);
    viewer.Figure.CloseRequestFcn = @(source, ~) ...
        dsap_finish_cine_preview(source, 'back', browser);
    if isgraphics(browser)
        setappdata(browser, 'PreviewFigure', viewer.Figure);
    end
    figure(viewer.Figure);
end

function display_sequence = scale_sequence_for_preview(sequence)
    minimum = double(min(sequence, [], 'all'));
    maximum = double(max(sequence, [], 'all'));
    if ~isfinite(minimum) || ~isfinite(maximum) || maximum <= minimum
        error('该 DSA 序列没有可用于动态预览的灰度范围。');
    end
    frame_count = size(sequence, 1);
    display_sequence = zeros(size(sequence), 'uint8');
    scale = 255 / (maximum - minimum);
    for frame = 1:frame_count
        dsap_task_control('check');
        current = double(squeeze(sequence(frame, :, :)));
        current = (current - minimum) * scale;
        display_sequence(frame, :, :) = uint8(min(max(round(current), 0), 255));
    end
end

function frame_signal = compute_preview_frame_signal(sequence)
    frame_count = size(sequence, 1);
    baseline = double(squeeze(sequence(1, :, :)));
    frame_signal = zeros(frame_count, 1);
    for frame = 1:frame_count
        dsap_task_control('check');
        current = double(squeeze(sequence(frame, :, :)));
        frame_signal(frame) = mean(abs(current - baseline), 'all');
    end
end

function toggle_cine_playback(fig, button)
    if ~isgraphics(fig)
        return;
    end
    if getappdata(fig, 'PreviewPlaying')
        setappdata(fig, 'PreviewPlaying', false);
        button.String = '播放';
        return;
    end

    setappdata(fig, 'PreviewPlaying', true);
    button.String = '暂停';
    preview_time = getappdata(fig, 'PreviewTime');
    frame_count = numel(preview_time);
    frame = get_viewer_frame(fig);
    if frame >= frame_count
        frame = 0;
    end
    while isgraphics(fig) && getappdata(fig, 'PreviewPlaying') && frame < frame_count
        frame = frame + 1;
        set_viewer_frame(fig, frame);
        drawnow;
        if frame < frame_count
            delay = preview_time(frame + 1) - preview_time(frame);
            pause(min(max(delay, 0.03), 0.25));
        end
    end
    if isgraphics(fig)
        setappdata(fig, 'PreviewPlaying', false);
        if isgraphics(button)
            button.String = '播放';
        end
    end
end

function finish_series_browser(browser, action)
    if isgraphics(browser)
        setappdata(browser, 'BrowserAction', action);
        uiresume(browser);
    end
end

function close_series_browser(browser)
    if isgraphics(browser)
        preview = getappdata(browser, 'PreviewFigure');
        if ~isempty(preview) && isgraphics(preview)
            preview.CloseRequestFcn = '';
            delete(preview);
        end
        uiresume(browser);
        delete(browser);
    end
end

function value = ternary_text(condition, true_value, false_value)
    if condition
        value = true_value;
    else
        value = false_value;
    end
end

function sequence = normalize_dicom_sequence(raw, info)
    sequence = squeeze(raw);
    if ndims(sequence) ~= 3
        error(['DICOM 像素数据在 squeeze 后必须是三维数组。', ...
            '当前尺寸为 %s；彩色或单帧文件暂不支持。'], mat2str(size(sequence)));
    end

    time_dimension = [];
    if isfield(info, 'NumberOfFrames')
        frame_count = double(info.NumberOfFrames);
        candidates = find(size(sequence) == frame_count);
        if ~isempty(candidates)
            time_dimension = candidates(end);
        end
    end
    if isempty(time_dimension)
        % Most XA multi-frame DICOM files use the last dimension for time.
        time_dimension = 3;
    end

    spatial_dimensions = setdiff(1:3, time_dimension, 'stable');
    sequence = permute(sequence, [time_dimension, spatial_dimensions]);
    if size(sequence, 1) < 3
        error('序列至少需要 3 个时间帧。');
    end
end

function frame_rate = detect_frame_rate(info)
    frame_rate = 15;
    if isfield(info, 'FrameTimeVector')
        frame_times = double(info.FrameTimeVector(:));
        frame_times = frame_times(isfinite(frame_times) & frame_times > 0);
        if ~isempty(frame_times)
            frame_rate = 1000 / median(frame_times);
            return;
        end
    end
    if isfield(info, 'FrameTime') && double(info.FrameTime) > 0
        frame_rate = 1000 / double(info.FrameTime);
    elseif isfield(info, 'CineRate') && double(info.CineRate) > 0
        frame_rate = double(info.CineRate);
    elseif isfield(info, 'RecommendedDisplayFrameRate') && ...
            double(info.RecommendedDisplayFrameRate) > 0
        frame_rate = double(info.RecommendedDisplayFrameRate);
    end
end

function [time_seconds, source] = build_acquisition_time_axis(info, frame_count, fallback_rate)
    time_seconds = [];
    source = 'fallback frame rate';

    if isfield(info, 'FrameTimeVector')
        frame_time_vector = double(info.FrameTimeVector(:));
        if numel(frame_time_vector) == frame_count
            % DICOM FrameTimeVector stores per-frame increments in ms. The
            % first item describes the first frame and is conventionally 0;
            % normalize the cumulative vector so the first frame is t = 0.
            increments_ms = frame_time_vector;
            increments_ms(1) = 0;
        elseif numel(frame_time_vector) == frame_count - 1
            % Accept exporters that omit the conventional leading zero.
            increments_ms = [0; frame_time_vector];
        else
            increments_ms = [];
            warning(['FrameTimeVector 含 %d 个值，但序列含 %d 帧；', ...
                '将改用备用帧率。'], numel(frame_time_vector), frame_count);
        end

        if ~isempty(increments_ms)
            valid_intervals = isfinite(increments_ms(2:end)) & increments_ms(2:end) > 0;
            if all(valid_intervals)
                time_seconds = cumsum(increments_ms) / 1000;
                time_seconds = time_seconds - time_seconds(1);
                source = 'DICOM FrameTimeVector cumulative';
            else
                warning('FrameTimeVector 含非正或无效帧间隔；将改用备用帧率。');
            end
        end
    end

    if isempty(time_seconds)
        time_seconds = (0:frame_count - 1)' / fallback_rate;
    end
end

function [resampled_sequence, uniform_time, dt] = ...
        resample_sequence_to_uniform_time(sequence, original_time)
    [resampled_sequence, uniform_time, dt] = ...
        dsap_resample_uniform(sequence, original_time);
end

function validate_sequence_settings(frame_rate, discard_frames, baseline_frames, total_frames)
    if ~isfinite(frame_rate) || frame_rate <= 0
        error('帧率必须是大于 0 的数字。');
    end
    if ~isfinite(discard_frames) || discard_frames < 0 || discard_frames >= total_frames - 2
        error('丢弃帧数必须是非负整数，并至少保留 3 帧。');
    end
    remaining_frames = total_frames - discard_frames;
    if ~isfinite(baseline_frames) || baseline_frames < 1 || baseline_frames >= remaining_frames
        error('基线帧数至少为 1，并且必须小于剩余总帧数。');
    end
end

function polarity = choose_contrast_polarity(bright_reference, dark_reference)
    preview = figure('Name', '选择造影增强方向', 'NumberTitle', 'off', ...
        'Color', 'w', 'Position', [180 150 1050 480]);
    layout = tiledlayout(preview, 1, 2, 'Padding', 'compact', ...
        'TileSpacing', 'compact');
    layout.Units = 'normalized';
    layout.Position = [0.02 0.17 0.96 0.80];
    ax1 = nexttile(layout);
    imshow(mat2gray(bright_reference), [], 'Parent', ax1);
    title(ax1, '造影后变亮');
    ax2 = nexttile(layout);
    imshow(mat2gray(dark_reference), [], 'Parent', ax2);
    title(ax2, '造影后变暗');
    choice = dsap_wait_for_review_choice(preview, ...
        '请选择血管显示最清楚的一侧。', ...
        {'血管变亮', 'bright'; '血管变暗', 'dark'; '取消分析', 'cancel'});
    close_if_valid(preview);
    if strcmp(choice, 'bright')
        polarity = 'bright';
    elseif strcmp(choice, 'dark')
        polarity = 'dark';
    else
        polarity = '';
    end
end

function [mask, aif, selected_frame, cancelled] = select_aif_roi(sequence, time_seconds)
    mask = [];
    aif = [];
    selected_frame = [];
    cancelled = false;
    viewer = create_sequence_viewer(sequence, '手动选择 AIF', ...
        '请先选择帧和绘图工具，再沿供血动脉绘制 AIF ROI');
    tool_labels = {'自由手绘', '多边形', '矩形', '圆形', '椭圆'};
    tool_values = {'freehand', 'polygon', 'rectangle', 'circle', 'ellipse'};
    tool_popup = uicontrol(viewer.Figure, 'Style', 'popupmenu', ...
        'Units', 'normalized', 'Position', [0.57 0.125 0.14 0.045], ...
        'String', tool_labels, 'Value', 1);
    status_text = uicontrol(viewer.Figure, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.57 0.015 0.39 0.035], ...
        'String', '选择工具后点击“绘制 AIF”；关闭确认窗会返回本页。', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    draw_button = uicontrol(viewer.Figure, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.72 0.12 0.11 0.055], ...
        'String', '绘制 AIF');
    cancel_button = uicontrol(viewer.Figure, 'Style', 'pushbutton', ...
        'Units', 'normalized', 'Position', [0.85 0.12 0.11 0.055], ...
        'String', '取消分析');
    next_button=uicontrol(viewer.Figure,'Style','pushbutton','Units','normalized', ...
        'Position',[.57 .065 .26 .045],'String','AIF Draft 完成，下一步','Enable','off', ...
        'Callback',@(~,~) accept_aif_draft(viewer.Figure));
    setappdata(viewer.Figure,'AIFDraftNext',next_button);

    setappdata(viewer.Figure, 'AIFSelectionAction', '');
    draw_button.Callback = @(source, ~) draw_aif_candidate( ...
        viewer, sequence, time_seconds, tool_popup, tool_values, ...
        status_text, source);
    cancel_button.Callback = @(~, ~) cancel_aif_selection(viewer.Figure);
    figure(viewer.Figure);
    drawnow;
    if isgraphics(viewer.Figure) && isempty(getappdata(viewer.Figure,'AIFSelectionAction'))
        uiwait(viewer.Figure);
    end

    if ~isgraphics(viewer.Figure)
        cancelled = true;
        return;
    end
    action = getappdata(viewer.Figure, 'AIFSelectionAction');
    if strcmp(action, 'accept') && isappdata(viewer.Figure, 'AIFSelectionResult')
        result = getappdata(viewer.Figure, 'AIFSelectionResult');
        mask = result.Mask;
        aif = result.Curve;
        selected_frame = result.Frame;
    else
        cancelled = true;
    end
    close_if_valid(viewer.Figure);
end

function draw_aif_candidate(viewer, sequence, time_seconds, tool_popup, ...
        tool_values, status_text, draw_button)
    fig = viewer.Figure;
    if ~isgraphics(fig) || ~isgraphics(tool_popup) || ~isgraphics(draw_button)
        return;
    end
    draw_button.Enable = 'off';
    cleanup_button = onCleanup(@() enable_control_if_valid(draw_button));
    tool = tool_values{tool_popup.Value};
    if isappdata(fig,'AIFDraftROI'),safe_delete_roi(getappdata(fig,'AIFDraftROI'));end
    next=getappdata(fig,'AIFDraftNext');next.Enable='off';
    status_text.String = '请在左侧影像上绘制闭合 AIF 区域。';
    drawnow;

    [candidate_mask, roi, draw_status] = draw_roi_mask( ...
        viewer.ImageAxes, tool, [1 0.35 0]);
    if strcmp(draw_status, 'cancelled') || ~isgraphics(fig)
        return;
    elseif ~strcmp(draw_status, 'accepted')
        status_text.String = '没有形成有效闭合区域，请再次点击“绘制 AIF”。';
        safe_delete_roi(roi);
        return;
    elseif nnz(candidate_mask) < 3
        status_text.String = 'AIF ROI 至少需要 3 个像素，请重新绘制。';
        safe_delete_roi(roi);
        return;
    end

    candidate_aif = mean(sequence(:, candidate_mask), 2);
    candidate_frame = get_viewer_frame(fig);
    cla(viewer.CurveAxes);
    plot(viewer.CurveAxes, time_seconds, candidate_aif, 'LineWidth', 1.8, ...
        'Color', [0.85 0.33 0.10]);
    grid(viewer.CurveAxes, 'on');
    xlabel(viewer.CurveAxes, '时间 (s)');
    ylabel(viewer.CurveAxes, '增强信号');
    title(viewer.CurveAxes, sprintf('AIF 曲线（绘制于第 %d 帧）', candidate_frame));

    result=struct('Mask',candidate_mask,'Curve',candidate_aif,'Frame',candidate_frame);
    setappdata(fig,'AIFSelectionResult',result);setappdata(fig,'AIFDraftROI',roi);
    next.Enable='on';status_text.String='可重新绘制，或进入下一步；将在总览页统一确认。';
    clear cleanup_button;
    enable_control_if_valid(draw_button);
end

function accept_aif_draft(fig)
    if isgraphics(fig)&&isappdata(fig,'AIFSelectionResult')
        setappdata(fig,'AIFSelectionAction','accept');uiresume(fig);
    end
end

function cancel_aif_selection(fig)
    if isempty(fig) || ~isgraphics(fig)
        return;
    end
    setappdata(fig, 'AIFSelectionAction', 'cancel');
    uiresume(fig);
end

function enable_control_if_valid(control)
    if ~isempty(control) && isgraphics(control)
        control.Enable = 'on';
    end
end

function [limit_mask, limits, cancelled] = ...
        select_cranial_vertical_limits(reference_image, aif_mask)
    rows = size(reference_image, 1);
    columns = size(reference_image, 2);
    limit_mask = false(rows, columns);
    limits = struct();
    cancelled = false;

    while true
        fig = figure('Name', '手动选择颅骨上下限', 'NumberTitle', 'off', ...
            'Color', 'w', 'Position', [150 70 920 820], ...
            'Pointer', 'crosshair');
        ax = axes(fig, 'Units', 'normalized', 'Position', [0.08 0.18 0.84 0.76]);
        imshow(reference_image, [], 'Parent', ax);
        hold(ax, 'on');
        visboundaries(ax, aif_mask, 'Color', [1 0.35 0], 'LineWidth', 1.2);
        title(ax, {'依次单击颅骨上限和颅骨下限', ...
            '仅两个水平界限之间的区域会进入颅内分析'});

        [~, first_row] = ginput(1);
        if isempty(first_row) || ~isgraphics(fig)
            close_if_valid(fig);
            cancelled = true;
            return;
        end
        provisional_row = max(1, min(rows, round(first_row)));
        line(ax, [0.5, columns + 0.5], [provisional_row, provisional_row], ...
            'Color', [0.1 1 1], 'LineWidth', 2);
        title(ax, '已选择第一条界限；请单击另一条颅骨界限');
        [~, second_row] = ginput(1);
        if isempty(second_row) || ~isgraphics(fig)
            close_if_valid(fig);
            cancelled = true;
            return;
        end
        selected_rows = [first_row; second_row];
        upper_row = max(1, min(rows, round(min(selected_rows))));
        lower_row = max(1, min(rows, round(max(selected_rows))));
        minimum_height = max(5, round(0.05 * rows));
        if lower_row - upper_row + 1 < minimum_height
            close_if_valid(fig);
            uiwait(warndlg('上下限距离过小，请重新选择。', '颅骨上下限'));
            continue;
        end

        candidate_mask = false(rows, columns);
        candidate_mask(upper_row:lower_row, :) = true;
        cla(ax);
        imshow(reference_image, [], 'Parent', ax);
        hold(ax, 'on');
        visboundaries(ax, aif_mask, 'Color', [1 0.35 0], 'LineWidth', 1.2);
        overlay_binary_mask(ax, candidate_mask, [0.1 0.85 1], 0.16);
        line(ax, [0.5, columns + 0.5], [upper_row, upper_row], ...
            'Color', [0.1 1 1], 'LineWidth', 2);
        line(ax, [0.5, columns + 0.5], [lower_row, lower_row], ...
            'Color', [1 0.85 0.1], 'LineWidth', 2);
        title(ax, sprintf('上限：第 %d 行（青色）；下限：第 %d 行（黄色）', ...
            upper_row, lower_row));

        choice = dsap_wait_for_review_choice(fig, ...
            '颅骨上下限 Draft：下一步进入组织分区，最终在总览页确认。', ...
            {'下一步', 'accept'; '重新选择', 'retry'; '取消分析', 'cancel'});
        close_if_valid(fig);
        if strcmp(choice, 'accept')
            limit_mask = candidate_mask;
            limits = struct( ...
                'Method', 'manual-horizontal-cranial-limits', ...
                'UpperRow', upper_row, ...
                'LowerRow', lower_row, ...
                'ImageRowCount', rows, ...
                'IncludedRowCount', lower_row - upper_row + 1);
            return;
        elseif strcmp(choice, 'retry')
            continue;
        else
            cancelled = true;
            return;
        end
    end
end

function [mask,model,features,cancelled]=review_signal_quality(reference,aif,limit_mask,limits,sequence,noise_map)
    sensitivity=0; cancelled=false;
    while true
        [mask,model,features]=dsap_classify_signal_quality(sequence,noise_map,limit_mask,sensitivity,reference);
        [rgb,~,~]=dsap_signal_quality_rgb(reference,features,limit_mask,false(size(mask)),aif,mask);
        fig=figure('Name','检查自动信号识别（不是全脑轮廓）','NumberTitle','off', ...
            'Color','w','Position',[100 90 1280 650]);
        layout=tiledlayout(fig,1,3,'Padding','compact','TileSpacing','compact');
        layout.Units='normalized'; layout.Position=[0.02 0.18 0.96 0.78];
        ax=nexttile(layout); imshow(reference,[],'Parent',ax); hold(ax,'on');
        draw_cranial_limit_lines(ax,limits);
        visboundaries(ax,features.ProjectionForegroundMask,'Color',[1 0.85 0.05],'LineWidth',1);
        title(ax,'黄色轮廓：最大增强投影的明暗边界');
        ax=nexttile(layout); imshow(rgb,'Parent',ax); title(ax,{'绿：检出持续增强；黄：弱/不稳定','灰：未检出增强（不等于零灌注）'});
        ax=nexttile(layout); imshow(features.SmoothedProjection,[],'Parent',ax);hold(ax,'on');
        visboundaries(ax,features.ProjectionForegroundMask,'Color',[1 0.85 0.05],'LineWidth',1);
        title(ax,sprintf('空间阈值 %.3f；时序阈值 %.2f 倍噪声',model.SpatialBoundary.AppliedThreshold,model.DetectionSNR));
        choice=dsap_wait_for_review_choice(fig,'先按投影明暗边界排除背景，再识别范围内的有效信号。', ...
            {'采用识别','accept';'保留更多弱信号','more';'更严格','less';'取消分析','cancel'});
        close_if_valid(fig);
        if strcmp(choice,'accept')
            if nnz(mask)>=3, return; end
            uiwait(warndlg('检出像素不足，请检查基线帧或保留更多弱信号。','信号识别'));
        elseif strcmp(choice,'more')
            sensitivity=min(2,sensitivity+0.5);
        elseif strcmp(choice,'less')
            sensitivity=max(-2,sensitivity-0.5);
        else
            cancelled=true; return;
        end
    end
end


function [mask,capillary,model,features,cancelled]=review_cave_vessel_mask(reference,aif,brain,scope,limits,model,features)
    [mask,capillary,model,features,cancelled]=dsap_review_cave_mask( ...
        reference,aif,brain,scope,limits,model,features,@draw_roi_mask);
end

function varargout = apply_capillary_mask(capillary_mask, varargin)
    varargout = varargin;
    for index = 1:numel(varargin)
        map = varargin{index};
        map(~capillary_mask) = NaN;
        varargout{index} = map;
    end
end

function overlay_binary_mask(ax, mask, color, opacity)
    overlay = zeros([size(mask), 3]);
    for channel = 1:3
        overlay(:, :, channel) = color(channel);
    end
    handle = imshow(overlay, 'Parent', ax);
    handle.AlphaData = opacity * double(mask);
end

function draw_cranial_limit_lines(ax, limits)
    if isempty(limits) || ~isstruct(limits) || ...
            ~isfield(limits, 'UpperRow') || ~isfield(limits, 'LowerRow')
        return;
    end
    x_limits = xlim(ax);
    line(ax, x_limits, [limits.UpperRow, limits.UpperRow], ...
        'Color', [0.1 1 1], 'LineWidth', 1.5, 'LineStyle', '--');
    line(ax, x_limits, [limits.LowerRow, limits.LowerRow], ...
        'Color', [1 0.85 0.1], 'LineWidth', 1.5, 'LineStyle', '--');
end

function [names, masks, roi_tics, roi_irfs, selected_frames, cancelled] = ...
        select_tissue_rois(sequence, aif_mask, large_vessel_mask, capillary_mask, ...
        tics, irfs, time_seconds)
    names = {};
    masks = {};
    roi_tics = {};
    roi_irfs = {};
    selected_frames = [];
    cancelled = false;
    viewer = create_sequence_viewer(sequence, '手动选择分析 ROI', ...
        '橙色为 AIF；请选择帧和工具后绘制分析 ROI');
    hold(viewer.ImageAxes, 'on');
    overlay_binary_mask(viewer.ImageAxes, large_vessel_mask, [1 0 0], 0.30);
    visboundaries(viewer.ImageAxes, aif_mask, ...
        'Color', [1 0.35 0], 'LineWidth', 1);

    roi_index = 1;
    while true
        name_answer = inputdlg('输入当前 ROI 名称：', 'ROI 名称', [1 36], ...
            {sprintf('ROI_%d', roi_index)});
        if isempty(name_answer)
            if isempty(masks)
                cancelled = true;
            end
            close_if_valid(viewer.Figure);
            return;
        end
        roi_name = strtrim(name_answer{1});
        if isempty(roi_name)
            roi_name = sprintf('ROI_%d', roi_index);
        end
        roi_name = make_unique_name(roi_name, names);

        tool = choose_roi_tool(sprintf('选择 %s 的绘图工具', roi_name));
        if isempty(tool)
            if isempty(masks)
                cancelled = true;
            end
            close_if_valid(viewer.Figure);
            return;
        end
        [candidate_mask, roi, draw_status] = draw_roi_mask( ...
            viewer.ImageAxes, tool, roi_color(roi_index));
        if strcmp(draw_status, 'cancelled')
            if isempty(masks)
                cancelled = true;
            end
            close_if_valid(viewer.Figure);
            return;
        elseif ~strcmp(draw_status, 'accepted')
            uiwait(warndlg(['没有得到有效的闭合 ROI。请重新绘制；', ...
                '关闭绘图窗口表示结束当前 ROI 选择。'], '分析 ROI'));
            safe_delete_roi(roi);
            continue;
        end
        if nnz(candidate_mask) < 3
            uiwait(warndlg('分析 ROI 至少需要包含 3 个像素。', '分析 ROI'));
            safe_delete_roi(roi);
            continue;
        end

        candidate_mask = candidate_mask & capillary_mask;
        if nnz(candidate_mask) < 3
            uiwait(warndlg(['ROI has fewer than 3 usable tissue pixels after ', ...
                'large-vessel removal. Please draw a larger tissue region.'], ...
                'Tissue ROI'));
            safe_delete_roi(roi);
            continue;
        end

        candidate_tic = mean(tics(:, candidate_mask), 2);
        candidate_irf = mean(irfs(:, candidate_mask), 2);
        candidate_frame = get_viewer_frame(viewer.Figure);
        cla(viewer.CurveAxes);
        yyaxis(viewer.CurveAxes, 'left');
        plot(viewer.CurveAxes, time_seconds, candidate_tic, 'b-', 'LineWidth', 1.8);
        ylabel(viewer.CurveAxes, 'TIC');
        yyaxis(viewer.CurveAxes, 'right');
        plot(viewer.CurveAxes, time_seconds, candidate_irf, 'r-', 'LineWidth', 1.5);
        ylabel(viewer.CurveAxes, 'IRF');
        xlabel(viewer.CurveAxes, '时间 (s)');
        title(viewer.CurveAxes, sprintf('%s（绘制于第 %d 帧）', ...
            roi_name, candidate_frame), 'Interpreter', 'none');
        grid(viewer.CurveAxes, 'on');

        choice = questdlg('是否采用当前分析 ROI？', '确认 ROI', ...
            '采用', '重新绘制', '结束分析', '采用');
        if strcmp(choice, '重新绘制')
            safe_delete_roi(roi);
            continue;
        elseif strcmp(choice, '结束分析')
            safe_delete_roi(roi);
            if isempty(masks)
                cancelled = true;
            end
            close_if_valid(viewer.Figure);
            return;
        end

        names{end + 1, 1} = roi_name; %#ok<AGROW>
        masks{end + 1, 1} = candidate_mask; %#ok<AGROW>
        roi_tics{end + 1, 1} = candidate_tic; %#ok<AGROW>
        roi_irfs{end + 1, 1} = candidate_irf; %#ok<AGROW>
        selected_frames(end + 1, 1) = candidate_frame; %#ok<AGROW>
        roi_index = roi_index + 1;

        add_more = questdlg('是否继续添加另一个分析 ROI？', '添加 ROI', ...
            '继续添加', '完成', '完成');
        if ~strcmp(add_more, '继续添加')
            close_if_valid(viewer.Figure);
            return;
        end
    end
end

function [names, masks, selected_frames, roi_types, merge_sources] = ...
        add_merged_roi_groups(names, masks, selected_frames, sequence)
    roi_types = repmat({'Individual'}, numel(names), 1);
    merge_sources = repmat({''}, numel(names), 1);
    if numel(masks) < 2
        return;
    end

    merge_index = 1;
    while true
        choice = questdlg(['是否把多个 ROI 合并为一个总体 ROI？', ...
            '原有单个 ROI 会保留，总体 ROI 将另行计算灌注参数和曲线。'], ...
            '合并 ROI', '添加合并 ROI', '不合并', '添加合并 ROI');
        if ~strcmp(choice, '添加合并 ROI')
            return;
        end

        [selection, accepted] = listdlg('PromptString', ...
            {'选择要合并的 ROI（至少 2 个）：', ...
             '可按 Ctrl 或 Shift 多选。'}, ...
            'SelectionMode', 'multiple', 'ListString', names, ...
            'InitialValue', 1:numel(names), 'ListSize', [520 300], ...
            'Name', '选择合并 ROI');
        if ~accepted
            return;
        end
        if numel(selection) < 2
            uiwait(warndlg('合并 ROI 至少需要选择 2 个 ROI。', '合并 ROI'));
            continue;
        end

        default_name = sprintf('总体ROI_%d', merge_index);
        name_answer = inputdlg('输入总体 ROI 名称：', '合并 ROI 名称', ...
            [1 40], {default_name});
        if isempty(name_answer)
            return;
        end
        merged_name = strtrim(name_answer{1});
        if isempty(merged_name)
            merged_name = default_name;
        end
        merged_name = make_unique_name(merged_name, names);

        merged_mask = false(size(masks{1}));
        for index = selection(:)'
            merged_mask = merged_mask | masks{index};
        end
        if nnz(merged_mask) < 3
            uiwait(warndlg('合并后的总体 ROI 少于 3 个像素。', '合并 ROI'));
            continue;
        end
        merged_curve = mean(sequence(:, merged_mask), 2);
        [~, merged_frame] = max(merged_curve);
        source_names = names(selection);

        names{end + 1, 1} = merged_name; %#ok<AGROW>
        masks{end + 1, 1} = merged_mask; %#ok<AGROW>
        selected_frames(end + 1, 1) = merged_frame; %#ok<AGROW>
        roi_types{end + 1, 1} = 'Merged'; %#ok<AGROW>
        merge_sources{end + 1, 1} = strjoin(source_names, ' + '); %#ok<AGROW>
        merge_index = merge_index + 1;

        add_more = questdlg('是否继续创建另一个总体 ROI？', '合并 ROI', ...
            '继续创建', '完成', '完成');
        if ~strcmp(add_more, '继续创建')
            return;
        end
    end
end

function [roi_tics, roi_irfs, original_roi_tics] = ...
        extract_roi_curves(masks, filtered_tics, irfs, original_sequence,irf_masks)
    if nargin<5,irf_masks=masks;end
    roi_tics = cell(numel(masks), 1);
    roi_irfs = cell(numel(masks), 1);
    original_roi_tics = cell(numel(masks), 1);
    for index = 1:numel(masks)
        mask = masks{index};
        roi_tics{index} = mean(filtered_tics(:, mask), 2);
        roi_irfs{index} = mean(irfs(:, irf_masks{index}), 2);
        original_roi_tics{index} = mean(original_sequence(:, mask), 2);
    end
end

function curves = extract_mask_mean_curves(masks, sequence)
    curves = cell(numel(masks), 1);
    for index = 1:numel(masks)
        curves{index} = mean(sequence(:, masks{index}), 2);
    end
end

function [aif_curve, roi_curves, native_capture] = extract_native_dicom_curves( ...
        source_file, info, discard_frames, onset_frame_after_discard, ...
        aif_mask, roi_masks,capture_native)
    raw = dicomread(source_file);
    native_sequence = normalize_dicom_sequence(raw, info);
    clear raw;
    first_frame = discard_frames + onset_frame_after_discard;
    if first_frame > size(native_sequence, 1) - 2
        error('原始灰度 TIC 的裁剪起点过晚，剩余帧数不足 3 帧。');
    end
    native_sequence = single(native_sequence(first_frame:end, :, :));
    aif_curve = mean(native_sequence(:, aif_mask), 2);
    roi_curves = extract_mask_mean_curves(roi_masks, native_sequence);
    native_capture=[];if capture_native,native_capture=native_sequence;end
    clear native_sequence;
end

function viewer = create_sequence_viewer(sequence, figure_name, instruction)
    % Graphics only need the normalized 0-255 display values. Storing a
    % double sequence in guidata makes each 1024x1024 frame eight times
    % larger and slows every CData update.
    display_sequence = viewer_sequence_uint8(sequence);
    frame_count = size(display_sequence, 1);
    frame_signal = zeros(frame_count, 1);
    for frame = 1:frame_count
        dsap_task_control('check');
        frame_signal(frame) = sum(display_sequence(frame, :, :), 'all', 'double');
    end
    [~, initial_frame] = max(frame_signal);

    fig = figure('Name', figure_name, 'NumberTitle', 'off', 'Color', 'w', ...
        'Position', [70 70 1320 700], 'MenuBar', 'figure', 'ToolBar', 'figure');
    setappdata(fig, 'UserCancelled', false);
    fig.CloseRequestFcn = @(source, ~) dsap_cancel_interactive_figure(source);
    image_ax = axes(fig, 'Units', 'normalized', 'Position', [0.04 0.20 0.47 0.73]);
    curve_ax = axes(fig, 'Units', 'normalized', 'Position', [0.57 0.20 0.39 0.73]);
    image_handle = imshow(squeeze(display_sequence(initial_frame, :, :)), [0 255], ...
        'Parent', image_ax);
    colormap(image_ax, gray(256));

    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.04 0.125 0.075 0.035], 'String', '帧号', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    frame_slider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.10 0.13 0.28 0.035], 'Min', 1, 'Max', frame_count, ...
        'Value', initial_frame, 'SliderStep', [1 / (frame_count - 1), ...
        min(10, frame_count - 1) / (frame_count - 1)]);
    frame_edit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.39 0.125 0.055 0.045], 'String', num2str(initial_frame));
    frame_total = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.445 0.125 0.065 0.035], ...
        'String', sprintf('/ %d', frame_count), 'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left'); %#ok<NASGU>

    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.04 0.065 0.075 0.035], 'String', '窗中心', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    center_slider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.10 0.07 0.16 0.035], 'Min', 0, 'Max', 255, 'Value', 127.5);
    uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.27 0.065 0.065 0.035], 'String', '窗宽', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    width_slider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.32 0.07 0.13 0.035], 'Min', 1, 'Max', 255, 'Value', 255);
    window_label = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.57 0.075 0.19 0.035], 'String', '', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    auto_checkbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
        'Position', [0.76 0.075 0.13 0.035], 'String', '换帧自动亮度', ...
        'Value', 1, 'BackgroundColor', 'w');
    auto_button = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.89 0.065 0.07 0.05], 'String', '自动亮度');

    data = struct('Sequence', display_sequence, 'Instruction', instruction, ...
        'ImageAxes', image_ax, 'CurveAxes', curve_ax, 'ImageHandle', image_handle, ...
        'FrameSlider', frame_slider, 'FrameEdit', frame_edit, ...
        'CenterSlider', center_slider, 'WidthSlider', width_slider, ...
        'WindowLabel', window_label, 'AutoCheckbox', auto_checkbox, ...
        'CurrentFrame', initial_frame, 'AutoWindowUpper', NaN(frame_count, 1));
    guidata(fig, data);

    frame_slider.Callback = @(source, ~) set_viewer_frame(fig, round(source.Value));
    frame_edit.Callback = @(source, ~) set_viewer_frame(fig, str2double(source.String));
    center_slider.Callback = @(~, ~) manual_window_changed(fig);
    width_slider.Callback = @(~, ~) manual_window_changed(fig);
    auto_button.Callback = @(~, ~) auto_window_current_frame(fig);
    set_viewer_frame(fig, initial_frame);

    viewer = struct('Figure', fig, 'ImageAxes', image_ax, 'CurveAxes', curve_ax);
end

function display_sequence = viewer_sequence_uint8(sequence)
    if isa(sequence, 'uint8')
        display_sequence = sequence;
        return;
    end
    display_sequence = zeros(size(sequence), 'uint8');
    for frame = 1:size(sequence, 1)
        dsap_task_control('check');
        current = double(squeeze(sequence(frame, :, :)));
        current(~isfinite(current)) = 0;
        display_sequence(frame, :, :) = uint8(min(max(round(current), 0), 255));
    end
end

function set_viewer_frame(fig, requested_frame)
    data = guidata(fig);
    if ~isfinite(requested_frame)
        requested_frame = data.CurrentFrame;
    end
    requested_frame = min(max(round(requested_frame), 1), size(data.Sequence, 1));
    data.CurrentFrame = requested_frame;
    data.FrameSlider.Value = requested_frame;
    data.FrameEdit.String = num2str(requested_frame);
    data.ImageHandle.CData = squeeze(data.Sequence(requested_frame, :, :));
    guidata(fig, data);
    title(data.ImageAxes, {data.Instruction, ...
        sprintf('当前第 %d / %d 帧', requested_frame, size(data.Sequence, 1))}, ...
        'Interpreter', 'none');
    if data.AutoCheckbox.Value
        auto_window_current_frame(fig);
    else
        update_viewer_window(fig);
    end
end

function frame = get_viewer_frame(fig)
    data = guidata(fig);
    frame = data.CurrentFrame;
end

function update_viewer_window(fig)
    data = guidata(fig);
    center = data.CenterSlider.Value;
    width = max(data.WidthSlider.Value, 1);
    lower = max(0, center - width / 2);
    upper = min(255, center + width / 2);
    if upper <= lower
        upper = min(255, lower + 1);
        lower = max(0, upper - 1);
    end
    caxis(data.ImageAxes, [lower upper]);
    data.WindowLabel.String = sprintf('显示范围 %.1f - %.1f', lower, upper);
end

function manual_window_changed(fig)
    data = guidata(fig);
    data.AutoCheckbox.Value = 0;
    guidata(fig, data);
    update_viewer_window(fig);
end

function auto_window_current_frame(fig)
    data = guidata(fig);
    cached_upper = data.AutoWindowUpper(data.CurrentFrame);
    if isfinite(cached_upper)
        lower = 0;
        upper = cached_upper;
    elseif isempty(data.ImageHandle.CData)
        lower = 0;
        upper = 255;
    else
        frame_data = data.ImageHandle.CData(:);
        lower = 0;
        % The viewer stores uint8 pixels, so a 256-bin histogram gives the
        % exact 99.5th percentile without sorting roughly one million
        % values on every frame change.
        counts = imhist(frame_data, 256);
        counts(1) = 0;
        valid_count = sum(counts);
        if valid_count == 0
            upper = 255;
        else
            upper_bin = find(cumsum(counts) >= 0.995 * valid_count, 1, 'first');
            upper = max(1, upper_bin - 1);
        end
    end
    data.AutoWindowUpper(data.CurrentFrame) = upper;
    width = min(255, max(1, upper - lower));
    center = min(255, max(0, (upper + lower) / 2));
    data.CenterSlider.Value = center;
    data.WidthSlider.Value = width;
    guidata(fig, data);
    update_viewer_window(fig);
end

function tool = choose_roi_tool(dialog_title)
    labels = {'自由手绘', '多边形', '矩形', '圆形', '椭圆'};
    values = {'freehand', 'polygon', 'rectangle', 'circle', 'ellipse'};
    [selection, accepted] = listdlg('PromptString', '选择绘制工具：', ...
        'SelectionMode', 'single', 'ListString', labels, ...
        'InitialValue', 1, 'Name', dialog_title, 'ListSize', [260 150]);
    if accepted
        tool = values{selection};
    else
        tool = '';
    end
end

function roi = draw_roi_shape(ax, tool, color)
    switch tool
        case 'freehand'
            roi = drawfreehand(ax, 'Color', color, 'LineWidth', 1.5);
        case 'smoothfreehand'
            roi = drawfreehand(ax, 'Color', color, 'LineWidth', 1.8, ...
                'Smoothing', 1);
        case 'polygon'
            roi = drawpolygon(ax, 'Color', color, 'LineWidth', 1.5);
        case 'rectangle'
            roi = drawrectangle(ax, 'Color', color, 'LineWidth', 1.5);
        case 'circle'
            roi = drawcircle(ax, 'Color', color, 'LineWidth', 1.5);
        case 'ellipse'
            roi = drawellipse(ax, 'Color', color, 'LineWidth', 1.5);
        otherwise
            error('未知 ROI 绘图工具：%s', tool);
    end
end

function [mask, roi, status] = draw_roi_mask(ax, tool, color)
    mask = [];
    roi = [];
    status = 'invalid';
    if isempty(ax) || ~isgraphics(ax)
        status = 'cancelled';
        return;
    end
    fig = ancestor(ax, 'figure');
    if isempty(fig) || ~isgraphics(fig)
        status = 'cancelled';
        return;
    end
    setappdata(fig, 'DrawingActive', true);
    cleanup_drawing = onCleanup(@() mark_drawing_inactive(fig));
    try
        roi = draw_roi_shape(ax, tool, color);
    catch ME
        if ~isgraphics(fig) || get_boolean_appdata(fig, 'UserCancelled')
            status = 'cancelled';
            return;
        end
        warning('DSAP:ROIDrawingFailed', ...
            'ROI 绘制未完成：%s', ME.message);
        status = 'invalid';
        return;
    end
    clear cleanup_drawing;
    if ~isgraphics(fig) || get_boolean_appdata(fig, 'UserCancelled')
        status = 'cancelled';
        return;
    end
    if isempty(roi)
        status = 'invalid';
        return;
    end
    try
        valid_roi = all(isvalid(roi(:)));
        position = roi.Position;
    catch
        valid_roi = false;
        position = [];
    end
    if ~valid_roi || isempty(position)
        status = 'invalid';
        return;
    end
    try
        mask = createMask(roi);
    catch ME
        warning('DSAP:ROIMaskFailed', ...
            '闭合曲线未能转换为掩膜：%s', ME.message);
        mask = [];
        status = 'invalid';
        return;
    end
    if ~islogical(mask)
        mask = logical(mask);
    end
    status = 'accepted';
end

function mark_drawing_inactive(fig)
    if ~isempty(fig) && isgraphics(fig)
        setappdata(fig, 'DrawingActive', false);
    end
end

function value = get_boolean_appdata(fig, name)
    value = false;
    if ~isempty(fig) && isgraphics(fig) && isappdata(fig, name)
        candidate = getappdata(fig, name);
        value = isscalar(candidate) && logical(candidate);
    end
end

function safe_delete_roi(roi)
    if isempty(roi)
        return;
    end
    try
        valid = isvalid(roi);
        delete(roi(valid));
    catch
        % The parent figure may already have deleted the ROI.
    end
end

function name = make_unique_name(name, existing_names)
    original_name = name;
    suffix = 2;
    while any(strcmpi(name, existing_names))
        name = sprintf('%s_%d', original_name, suffix);
        suffix = suffix + 1;
    end
end

function color = roi_color(index)
    colors = lines(max(7, index));
    color = colors(index, :);
end

function result=calculate_vessel_roi_results(result,maps,tics,irfs,original,time,volume,peak,ttp,intensity)
    cbf=maps{1};cbv=maps{2};tmax=maps{3};mtt=maps{4};
    scope=result.Masks{1}|result.Masks{2};
    valid=isfinite(cbf)&isfinite(cbv)&isfinite(tmax)&isfinite(mtt)&cbf>0&cbv>0;
    if any(scope,'all')
        [cbf,cbv,tmax,mtt]=postprocess_maps(cbf,cbv,tmax,mtt,scope);
        valid=valid&cbf>max(cbf(scope),[],'all')*1e-4;
    else
        valid(:)=false;
    end
    valid=valid&scope;
    cbf(~valid)=NaN;cbv(~valid)=NaN;tmax(~valid)=NaN;mtt(~valid)=NaN;
    result.ParameterMasks=cellfun(@(m)m&valid,result.Masks,'UniformOutput',false);
    [result.TIC,result.IRF,result.OriginalTIC]=extract_roi_curves(result.Masks,tics,irfs,original,result.ParameterMasks);
    result.Summary=build_summary_table(result.Names,result.Masks,[NaN;NaN],result.Types,{'';''}, ...
        cbf,cbv,tmax,mtt,volume,peak,ttp,intensity,result.IRF,time);
    geometry=cellfun(@nnz,result.GeometryMasks);counts=cellfun(@nnz,result.Masks);
    good=cellfun(@nnz,result.ParameterMasks);zero=zeros(2,1);coverage=100*good./max(counts,1);
    coverage(counts==0)=NaN;
    result.Coverage=table(result.Names,geometry,zero,zero,geometry-counts,counts,good,counts-good,coverage, ...
        'VariableNames',{'ROI','GeometryPixels','ExcludedVesselPixels','ExcludedAIFPixels', ...
        'NonfiniteInputPixels','TICPixels','PerfusionValidPixels','InvalidPerfusionPixels','PerfusionCoveragePercent'});
    result.ParameterMaps=struct('CBF',cbf,'CBV',cbv,'Tmax',tmax,'MTT',mtt);
    result.Status=repmat({'ok'},2,1);
    for k=1:2
        if counts(k)==0,result.Status{k}='empty ROI; parameters/TIC unavailable';
        elseif good(k)==0,result.Status{k}='no valid deconvolution; TIC retained';end
    end
end

function [CBF, CBV, Tmax, MTT] = postprocess_maps(CBF, CBV, Tmax, MTT,numerical_scope)
    if nargin<5,numerical_scope=true(size(CBF));end
    CBF(~isfinite(CBF)) = 0;
    CBV(~isfinite(CBV)) = 0;
    Tmax(~isfinite(Tmax)) = 0;
    MTT(~isfinite(MTT)) = 0;

    invalid_volume = CBV <= 0;
    CBF(invalid_volume) = 0;
    CBV(invalid_volume) = 0;
    Tmax(invalid_volume) = 0;
    MTT(invalid_volume) = 0;

    % Use a scale-relative numerical floor; CBF is not clinically calibrated.
    low_flow = CBF <= max(CBF(numerical_scope), [], 'all') * 1e-4;
    Tmax(low_flow) = 0;
    MTT(low_flow) = 0;
    Tmax = medfilt2(Tmax);
    MTT = medfilt2(MTT);
end

function summary = build_summary_table(names, masks, selected_frames, roi_types, ...
        merge_sources, CBF, CBV, Tmax, MTT, volume_map, peak_map, ttp_map, ...
        intensity_map, roi_irfs, time_seconds)
    count = numel(masks);
    roi_name = names(:);
    roi_type = roi_types(:);
    merged_from = merge_sources(:);
    selected_frame = selected_frames(:);
    area_pixels = zeros(count, 1);
    cbf_mean = zeros(count, 1);
    cbv_mean = zeros(count, 1);
    tmax_mean_s = zeros(count, 1);
    mtt_mean_s = zeros(count, 1);
    volume_mean = zeros(count, 1);
    peak_mean = zeros(count, 1);
    ttp_mean_s = zeros(count, 1);
    intensity_mean = zeros(count, 1);
    roi_irf_cbf = zeros(count, 1);
    roi_irf_cbv = zeros(count, 1);
    roi_irf_tmax_s = zeros(count, 1);
    roi_irf_mtt_s = zeros(count, 1);
    dt = median(diff(time_seconds));

    for index = 1:count
        mask = masks{index};
        area_pixels(index) = nnz(mask);
        cbf_mean(index) = mean(CBF(mask), 'omitnan');
        cbv_mean(index) = mean(CBV(mask), 'omitnan');
        tmax_mean_s(index) = mean(Tmax(mask), 'omitnan');
        mtt_mean_s(index) = mean(MTT(mask), 'omitnan');
        volume_mean(index) = mean(volume_map(mask), 'omitnan');
        peak_mean(index) = mean(peak_map(mask), 'omitnan');
        ttp_mean_s(index) = mean(ttp_map(mask), 'omitnan');
        intensity_mean(index) = mean(intensity_map(mask), 'omitnan');
        mean_irf = double(roi_irfs{index}(:));
        if ~any(isfinite(mean_irf))
            roi_irf_cbf(index)=NaN;roi_irf_cbv(index)=NaN;roi_irf_tmax_s(index)=NaN;roi_irf_mtt_s(index)=NaN;
            continue;
        end
        [roi_irf_cbf(index), peak_index] = max(mean_irf);
        roi_irf_tmax_s(index) = time_seconds(peak_index);
        roi_irf_cbv(index) = dt * sum(mean_irf, 'omitnan');
        roi_irf_mtt_s(index) = roi_irf_cbv(index) / ...
            max(roi_irf_cbf(index), eps);
    end

    summary = table(roi_name, roi_type, merged_from, selected_frame, ...
        area_pixels, cbf_mean, cbv_mean, ...
        tmax_mean_s, mtt_mean_s, volume_mean, peak_mean, ttp_mean_s, ...
        intensity_mean, roi_irf_cbf, roi_irf_cbv, roi_irf_tmax_s, ...
        roi_irf_mtt_s, 'VariableNames', {'ROI', 'ROIType', 'MergedFrom', ...
        'SelectedFrame', 'AreaPixels', 'CBF', 'CBV', 'Tmax_s', 'MTT_s', ...
        'Volume', 'Peak', 'TTP_s', 'Intensity', 'ROIIRF_CBF', 'ROIIRF_CBV', ...
        'ROIIRF_Tmax_s', 'ROIIRF_MTT_s'});
end

function output_dir = make_output_directory(project_dir, filename)
    [~, stem] = fileparts(filename);
    if isempty(stem)
        stem = 'DSA';
    end
    stem = regexprep(stem, '[^a-zA-Z0-9_-]', '_');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_dir = fullfile(project_dir, 'interactive_results', ...
        sprintf('%s_%s', stem, timestamp));
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
end

function label_mask_center(ax, mask, label, color)
    stats = regionprops(logical(mask), 'Centroid', 'Area');
    if isempty(stats)
        return;
    end
    [~, largest] = max([stats.Area]);
    center = stats(largest).Centroid;
    text(ax, center(1), center(2), [' ', label], ...
        'Color', color, 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', 'k', 'Margin', 1, 'Interpreter', 'none');
end

function label = roi_display_label(roi_name, fallback_index)
    token = regexp(roi_name, 'TIMESlice_ROI_(\d+)$', 'tokens', 'once');
    if isempty(token)
        label = sprintf('ROI %02d', fallback_index);
    else
        label = sprintf('ROI %s', token{1});
    end
end

function show_map(ax, data, map_title)
    h=imagesc(ax, data);
    h.AlphaData=single(isfinite(data));
    ax.Color=[0.65 0.65 0.65];
    axis(ax, 'image', 'off');
    title(ax, [map_title '（灰色不参与统计）']);
    colorbar(ax);
end

function close_if_valid(handle)
    if ~isempty(handle) && isgraphics(handle)
        try
            handle.CloseRequestFcn = '';
        catch
        end
        delete(handle);
        drawnow limitrate nocallbacks;
    end
end
