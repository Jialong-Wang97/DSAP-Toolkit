function network=prepare_lumen_geometry(mask,network)
% Cacheable existing Auto-AIF geometry; no TDC, ROI or scientific changes.
 root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src','geometry'));
 % Reuse the existing skeleton graph adapter, never rerun vessel recognition.
 if isempty(network),network=build_centerline_graph(mask,[1 1]);
 elseif isstruct(network)&&isfield(network,'ICACenterline')&&~isfield(network,'Graph')
  supplied=network.ICACenterline;network=build_centerline_graph(mask,[1 1]);network.ICACenterline=supplied;
 end
 assert(isstruct(network)&&isfield(network,'Graph')&&isfield(network,'XY'),'AutoAIF:Network','缺少有效中心线 graph。');
 g=network.Graph;xy=double(network.XY);ij=round(xy);
 assert(isa(g,'graph')&&size(xy,1)==numnodes(g)&&size(xy,2)==2&&all(isfinite(xy),'all')&& ...
  all(ij(:,1)>=1&ij(:,1)<=size(mask,2)&ij(:,2)>=1&ij(:,2)<=size(mask,1)), 'AutoAIF:Network','中心线 graph 坐标无效。');
 idx=sub2ind(size(mask),ij(:,2),ij(:,1));assert(all(mask(idx)),'AutoAIF:Network','中心线不在血管内。');
 e=g.Edges.EndNodes;assert(isnumeric(e),'AutoAIF:Network','中心线节点必须使用数值索引。');
 g.Edges.Weight=vecnorm(xy(e(:,1),:)-xy(e(:,2),:),2,2);
 dt=bwdist(~padarray(mask,[1 1],false,'both'));dt=dt(2:end-1,2:end-1);
 branch=false(size(mask));branch(idx(degree(g)>=3))=true;
 % Euclidean distance excludes nearby branch arms, not just along-path nodes.
 if any(branch,'all'),branchDistance=bwdist(branch);else,branchDistance=inf(size(mask));end
 method='provided ICA centerline';
 if isfield(network,'ICACenterline')&&~isempty(network.ICACenterline)
  path=double(network.ICACenterline);
 else
  method='thick main-trunk ICA candidate (unlabelled)';
  bins=conncomp(g);lengths=accumarray(bins(e(:,1))',g.Edges.Weight,[max(bins) 1]);
  [~,component]=max(lengths);nodes=find(bins==component);ends=nodes(degree(g,nodes)==1);
  assert(numel(ends)>=2,'AutoAIF:Trunk','中心线没有可追踪的主干端点。');
  merit=zeros(size(ends));
  for k=1:numel(ends)
   d=distances(g,ends(k));near=d<=max(5,2*dt(idx(ends(k))));merit(k)=median(dt(idx(near)));
  end
  [~,k]=max(merit);origin=ends(k);best=-inf;destination=[];
  for endpoint=reshape(ends,1,[])
   if endpoint==origin,continue;end
   route=shortestpath(g,origin,endpoint);value=sum(dt(idx(route)).^2);
   if value>best,best=value;destination=endpoint;end
  end
  % Call the established centerline module unchanged for ordered trunk tracing.
  path=extractOrderedVesselPath(mask,xy(origin,:),xy(destination,:),[],struct('PathMethod','skeleton'));
 end
 assert(size(path,2)==2&&size(path,1)>=5&&all(isfinite(path),'all'),'AutoAIF:Path','ICA 中心线过短或无效。');
 p=round(path);assert(all(p(:,1)>=1&p(:,1)<=size(mask,2)&p(:,2)>=1&p(:,2)<=size(mask,1)),'AutoAIF:Path','ICA 中心线越界。');
 pi=sub2ind(size(mask),p(:,2),p(:,1));assert(all(mask(pi)),'AutoAIF:Path','ICA 中心线不在血管腔内。');
 radius=double(dt(pi));arc=[0;cumsum(vecnorm(diff(path),2,2))];
 assert(all(diff(arc)>0),'AutoAIF:Path','中心线存在重复点。');
 % Existing smoothed/resampled curvature computation; no change to that module.
 geometry=computeVesselGeometry(path,[],struct('UseVTI',false,'SmoothingStrength',max(5,median(radius))));
 assert(geometry.Valid,'AutoAIF:Geometry','%s',geometry.Warning);
 curvature=interp1(linspace(0,arc(end),numel(geometry.CurvatureProfile)),geometry.CurvatureProfile,arc,'linear');
 clearance=double(branchDistance(pi));minRadius=max(2,.5*prctile(radius,90));
 eligible=radius>=minRadius & clearance>=2*radius & arc>=2*radius & arc(end)-arc>=2*radius;
 prepared.Anatomy=struct('Method',method,'C4C5Assigned',false);
 prepared.Centerline=path;prepared.Geometry=table(path(:,1),path(:,2),radius,curvature,clearance,eligible, ...
  'VariableNames',{'X_px','Y_px','Radius_px','Curvature_per_px','BranchDistance_px','Eligible'});
 prepared.Arc=arc;prepared.Mask=mask;prepared.RadiusMap_px=dt;
 network.PreparedGeometry=prepared;
end
