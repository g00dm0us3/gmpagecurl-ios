# gmpagecurl-ios - Under Construction
A page curl effect for iOS using Metal.

## TODO
### Short Term
- Document! Lest I forget what the hell was this all about!
- Clean up code
    - ~~Remove GLMatrix functions~~
    - Make view autoresizable (override view's layerSubclass to return CAMetalLayer)
    - ~~Remove unused code at this point - depth testing / light (both shader and project, put it in a garbage file)~~
    - General refactoring
- Add rotation / zooming gestures, along with 𝛗 / displacement selection selection (for demo).
- Add switch btw. rectangular (box, first step), and cylindrical views.


### Long Term
- Adjust perspective trasformation matrix, to better reflect the effect of curl
- 𝛗 / displacement controlled by gesture
- Light
- Textures
- Render arbitrary views into textures (switcharoo when user starts dragging).
- Package as pod (whtv)

