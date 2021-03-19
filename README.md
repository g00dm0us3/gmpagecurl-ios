# gmpagecurl-ios - RC 1.0
An open-source page curl effect for iOS using Metal. A rustic alternative to ```UIPageViewController```

![What is this](page_curl_demo.gif)

## How it works

The idea behind the implementation is simple - a cylinder slides across the surface of a sheet of paper. Sheet of paper curves around its right side and flats out on the top. If it slides from right to left, we consider it to be a flip forward, if it's in reverse flip backward. Cylinder has an axis, which can be best described by a line drawn on a sheet of paper, where cylinder touches it at any given moment. The key parameters of the cylinder at any given moment are: 𝞿 - an angle between perpendicular to cylinder axis and x - axis, and delta - an offset from right of a cylinder axis. Cylinder's position is completely determined by it's axis. Also, cylinder has a constant radius.

Cylinder's axis is also reffered as "inflection border", due to the way the effect is implemented. At first we build a reectangular prism - to invision it, take a sheet of paper and bend it twice along any two parralell lines. Then, the vector is drawn from cylinder's true axis - the line which actually goes through cylinder's center, to the point on the resulting prism. Then the vector is normalized, and mutliplied by cylinder radius. The set of such normalized vectors results in a surface, curved around cylinder's axis.

## Anatomy of a solution
### Render pass
Each render pass consists of three passes: computational, shadow, and color pass. Computational pass first computes vertex positions (sheet deformation) based on 𝞿 and delta, which come from user's pan gesture, and then it computes normals at each point. The need for computational pass is due to the fact, that Metal doesn't have geometry shaders. Although it was mentioned that tile shaders can be used to compute normals, I didn't find a direct way of doing so.

Shadow pass is used to calculate depth map, which is later used for shadow calculation in color fragment shader. Shadow passes's vertex shader simply computes vertex positions from source of light point of view. 

Color pass puts all of the above together, along with the texture of custom ```UIView```, representing page.

## TODO

- [ ] Finish writing readme.
- [ ] Fix weird bug around first page flip back / forward.
- [ ] Implement MSAA toggle.
- [ ] Lock in portrait orientation.
- [] d𝛗/dx = C, 𝛗 -> 0 

