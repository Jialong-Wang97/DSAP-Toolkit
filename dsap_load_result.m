function r=dsap_load_result(folder)
% Also accepts pre-Core-Save results for explicitly requested re-export.
    state=load(fullfile(folder,'analysis_status.mat'),'analysis_complete');
    assert(state.analysis_complete,'DSAP:IncompleteCore','核心结果未完整保存，不能完整导出。');
    r=load(fullfile(folder,'interactive_perfusion_results.mat'));
    if ~isfield(r,'brain_mask')
        if isfield(r,'partition'),r.brain_mask=r.partition.OuterMask;
        elseif isfield(r,'timeslice_import'),r.brain_mask=r.partition_stats.OuterMask;
        else,r.brain_mask=r.signal_valid_mask;end
    end
end
