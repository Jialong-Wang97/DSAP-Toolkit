function value=dsap_session_cache(action,varargin)
% B+C: bounded packed RAM, or one owned temporary v7.3 file. No numeric casts.
    switch action
        case 'plan'
            inputs=varargin{1};domain=varargin{2};options=varargin{3};reserve=varargin{4};
            names={'filtered','irf','enhanced','native'};payload=0;shape=struct();types=struct();
            for k=1:4
                array=inputs.(names{k});w=whos('array');
                payload=payload+w.bytes/numel(domain)*nnz(domain);
                shape.(names{k})=[size(array,1),nnz(domain)];types.(names{k})=class(array);
            end
            [~,system]=memory;budget=min(options.RAMBudgetMiB*1024^2,.25*system.PhysicalMemory.Available);
            reserve=reserve+8*nnz(domain)+numel(domain); % pixel index + logical domain
            mode='ram';if payload+reserve>budget,mode='disk';end
            value=struct('Mode',mode,'PayloadBytes',payload,'BudgetBytes',budget,'ReserveBytes',reserve, ...
                'Domain',domain,'Indices',find(domain),'Shape',shape,'Types',types,'File','', ...
                'Id',char(java.util.UUID.randomUUID()),'Data',struct(),'Status','planned','CaptureSeconds',0);
            assert(payload<=options.DiskBudgetMiB*1024^2||strcmp(mode,'ram'), ...
                'DSAP:CacheBudget','编辑缓存超过磁盘预算；结果仍可保存，无法启用增量编辑。');
        case 'build'
            value=varargin{1};inputs=varargin{2};started=tic;
            names={'filtered','irf','enhanced','native'};
            if strcmp(value.Mode,'disk')
                parent=fullfile(tempdir,'dsap_session_cache');if ~isfolder(parent),mkdir(parent);end
                file=fullfile(parent,[value.Id '.mat']);value.File=file;
                free=java.io.File(parent).getUsableSpace();
                assert(free>value.PayloadBytes*1.1,'DSAP:CacheDiskSpace','临时缓存磁盘空间不足。');
                try
                    for k=1:4
                        part=struct();part.(names{k})=inputs.(names{k})(:,value.Indices);
                        if k==1,save(file,'-struct','part','-v7.3');else,save(file,'-struct','part','-append');end
                        clear part;
                    end
                    cache_id=value.Id;save(file,'cache_id','-append');
                catch exception
                    if isfile(file),delete(file);end
                    rethrow(exception);
                end
            else
                for k=1:4,value.Data.(names{k})=inputs.(names{k})(:,value.Indices);end
            end
            value.Status='valid';value.CaptureSeconds=toc(started);
        case 'samples'
            cache=varargin{1};name=varargin{2};mask=varargin{3};
            assert(strcmp(cache.Status,'valid'),'DSAP:CacheInvalid','编辑缓存无效。');
            assert(isequal(size(mask),size(cache.Domain))&&~any(mask&~cache.Domain,'all'), ...
                'DSAP:CacheCoverage','新 ROI 超出当前缓存覆盖；R1 不会隐式重算。');
            columns=find(mask(cache.Indices));
            if strcmp(cache.Mode,'ram'),value=cache.Data.(name)(:,columns);return;end
            assert(isfile(cache.File),'DSAP:CacheMissing','临时缓存已丢失；请重新完整分析以建立缓存。');
            file=matfile(cache.File);assert(strcmp(file.cache_id,cache.Id),'DSAP:StaleCache','缓存身份不匹配。');
            frames=cache.Shape.(name)(1);value=zeros(frames,numel(columns),cache.Types.(name));
            if isempty(columns),return;end
            bytes=8;if strcmp(cache.Types.(name),'single'),bytes=4;end
            width=max(1,floor(32*1024^2/(frames*bytes)));
            for first=columns(1):width:columns(end)
                last=min(first+width-1,columns(end));selected=find(columns>=first&columns<=last);
                if isempty(selected),continue;end
                block=file.(name)(1:frames,first:last);
                value(:,selected)=block(:,columns(selected)-first+1);
            end
        case 'release'
            cache=varargin{1};value=[];
            if isfield(cache,'File')&&~isempty(cache.File)
                expected=fullfile(tempdir,'dsap_session_cache',[cache.Id '.mat']);
                assert(strcmp(cache.File,expected),'DSAP:CacheOwnership','拒绝清理非本会话缓存。');
                if isfile(expected),delete(expected);end
            end
        otherwise,error('DSAP:CacheAction','未知缓存操作。');
    end
end
