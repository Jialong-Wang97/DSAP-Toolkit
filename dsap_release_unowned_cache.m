function dsap_release_unowned_cache(cache)
% A failed save/window close must not orphan a newly built disk cache.
    if isempty(cache),return;end
    if dsap_analysis_session('active')
        current=dsap_analysis_session('get');if strcmp(current.Id,cache.Id),return;end
    end
    dsap_session_cache('release',cache);
end
