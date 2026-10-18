function xy=dsap_partition_curve(control)
% Periodic cubic B-spline; control vertices are handles, not jagged edges.
    validateattributes(control,{'numeric'},{'2d','ncols',2,'finite','real'});
    assert(size(control,1)>=4,'至少需要四个轮廓控制点。');
    count=size(control,1);t=(0:15)'/16;
    weights=[(1-t).^3,3*t.^3-6*t.^2+4,-3*t.^3+3*t.^2+3*t+1,t.^3]/6;
    xy=zeros(count*numel(t)+1,2);
    for k=1:count
        vertices=control(mod((k-2:k+1),count)+1,:);
        xy((k-1)*numel(t)+(1:numel(t)),:)=weights*vertices;
    end
    xy(end,:)=xy(1,:);
end
