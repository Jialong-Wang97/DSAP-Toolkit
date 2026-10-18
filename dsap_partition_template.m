function value=dsap_partition_template(action,varargin)
% Templates contain geometry only; no patient identifiers or gray levels.
    switch action
        case 'default'
            angle=(0:15)'*2*pi/16;
            outer=[0.5+0.49*cos(angle),0.5+0.49*sin(angle)];
            inner=0.5+0.68*(outer-0.5);
            value=struct('Format','DSAP-partition-template-v1','OuterNormalized',outer,'InnerNormalized',inner);
        case 'fitbox'
            reference=varargin{1};limits=varargin{2};
            band=dsap_validate_cranial_limits(limits,size(reference));
            foreground=dsap_mip_foreground(reference,band);
            [~,cols]=find(foreground);width=size(reference,2);
            if numel(cols)>20
                left=max(1,min(cols)-0.04*width);right=min(width,max(cols)+0.04*width);
            else
                left=0.06*width;right=0.94*width;
            end
            value=[left limits.UpperRow max(4,right-left) max(4,limits.LowerRow-limits.UpperRow)];
        case 'apply'
            template=varargin{1};box=varargin{2};
            assert(isstruct(template)&&isscalar(template)&& ...
                all(isfield(template,{'Format','OuterNormalized','InnerNormalized'})) && ...
                strcmp(template.Format,'DSAP-partition-template-v1'),'不是有效的 DSAP 分区模板。');
            validateattributes(template.OuterNormalized,{'numeric'},{'2d','ncols',2,'finite','real'});
            validateattributes(template.InnerNormalized,{'numeric'},{'2d','ncols',2,'finite','real'});
            assert(size(template.OuterNormalized,1)>=4&&size(template.InnerNormalized,1)>=4&& ...
                size(template.OuterNormalized,1)<=128&&size(template.InnerNormalized,1)<=128, ...
                '每条模板轮廓需要 4–128 个控制点。');
            value=struct('Outer',template.OuterNormalized.*box(3:4)+box(1:2), ...
                'Inner',template.InnerNormalized.*box(3:4)+box(1:2));
        case 'savegeometry'
            partition=varargin{1};box=varargin{2};
            value=struct('Format','DSAP-partition-template-v1', ...
                'OuterNormalized',(partition.OuterControlPoints-box(1:2))./box(3:4), ...
                'InnerNormalized',(partition.InnerControlPoints-box(1:2))./box(3:4));
        otherwise
            error('未知模板操作。');
    end
end
