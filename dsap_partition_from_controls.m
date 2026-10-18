function partition=dsap_partition_from_controls(outer_control,inner_control,image_size,limits)
% Final region definitions are geometric, never intersected with MIP/SNR.
    band=dsap_validate_cranial_limits(limits,image_size);
    outer_xy=dsap_partition_curve(outer_control);inner_xy=dsap_partition_curve(inner_control);
    assert(simple_curve(outer_xy)&&simple_curve(inner_xy),'DSAP:PartitionSelfIntersection', ...
        '轮廓发生自交，请调整控制点或撤销。');
    outer=poly2mask(outer_xy(:,1),outer_xy(:,2),image_size(1),image_size(2)) & band;
    inner=poly2mask(inner_xy(:,1),inner_xy(:,2),image_size(1),image_size(2)) & band;
    assert(nnz(outer)>=6 && nnz(inner)>=3,'DSAP:PartitionEmpty','轮廓面积太小或位于上下限以外。');
    assert(~any(inner & ~imerode(outer,ones(3)),'all'),'DSAP:PartitionNesting', ...
        '内轮廓必须位于外轮廓内，并留出外围带状区域；不会自动裁掉越界部分。');
    cortex=outer & ~inner;
    assert(nnz(cortex)>=3,'DSAP:PartitionEmpty','外围带状区域太小。');
    partition=struct('Method','editable-nested-periodic-bspline-v1', ...
        'Definition','cortex=outer-minus-inner; subcortex=inner; geometric projection regions', ...
        'OuterControlPoints',double(outer_control),'InnerControlPoints',double(inner_control), ...
        'OuterCurve',outer_xy,'InnerCurve',inner_xy,'OuterMask',outer, ...
        'CortexMask',cortex,'SubcortexMask',inner,'CranialLimits',limits, ...
        'ImageSize',image_size,'Confirmed',false,'AnatomicalAtlas',false);
end

function valid=simple_curve(xy)
    a=xy(1:end-1,:);b=xy(2:end,:);n=size(a,1);valid=true;
    for k=1:n-2
        j=(k+2:n)';if k==1,j(j==n)=[];end
        if isempty(j),continue;end
        direction=b(k,:)-a(k,:);other=b(j,:)-a(j,:);
        delta=a(j,:)-a(k,:);
        denominator=direction(1)*other(:,2)-direction(2)*other(:,1);
        usable=abs(denominator)>1e-10;
        t=(delta(:,1).*other(:,2)-delta(:,2).*other(:,1))./denominator;
        u=(delta(:,1)*direction(2)-delta(:,2)*direction(1))./denominator;
        if any(usable & t>1e-8 & t<1-1e-8 & u>1e-8 & u<1-1e-8),valid=false;return;end
    end
end
