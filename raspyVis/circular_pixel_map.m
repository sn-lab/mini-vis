%add parameters to adjust radius, clip sides
radius = 120;
clip = [0 30 0 0]; %[top, bottom, left, right] pixels to clip
magnify = 1; %just to make it easier to view

%for an array of size diameter*diameter, calculate the relative x/y 
%coordinates of every element with [0,0] being the center of the array
x = repmat((-radius+0.5):(radius-0.5), [radius*2 1]); %x-coordinate of array ([0 0] center)
y = repmat(((radius-0.5):-1:(-radius+0.5))',[1 radius*2]); %y-coordinate

%using the x and y coordinates, calculate the distance from the array center
dist_from_center = sqrt((x.^2)+(y.^2));

%anything inside the diameter get a 1, anything outside gets a zero
mask = dist_from_center; 
mask(mask<=radius) = 1;
mask(mask>radius) = 0;

%clip the array as needed
mask = mask(1+clip(1):end-clip(2),1+clip(3):end-clip(4));

%calculate number of unmasked pixels
unmasked_pixels = sum(sum(mask));
total_pixels = numel(mask);
unmasked_fraction = unmasked_pixels/total_pixels;
fprintf([num2str(unmasked_pixels) ' out of ' num2str(total_pixels) ...
    ' are unmasked (' num2str(unmasked_fraction*100) '%%)\n']);

%visualize the circular mask (magnify kron if it's too small)
imshow(kron(mask,ones(magnify)))