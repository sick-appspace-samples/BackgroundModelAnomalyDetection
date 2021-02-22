--[[----------------------------------------------------------------------------

  Application Name:
  BackgroundModel
                                                                                             
  Summary:
  Detecting object appearance deviations. This is done by first teaching
  how the object should look like on a number of "good" objects, and then
  detecting pixel regions deviating from the teached model.
   
  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the viewer on the DevicePage.
  
  More Information:
  Tutorial "Algorithms - Filtering and Arithmetic".

------------------------------------------------------------------------------]]

--Start of Global Scope---------------------------------------------------------

-- This is an area sensor so we select false here.
local lineScanSensor = false

-- Create a background model.
local meanThreshold = 0.0
local varianceThreshold = 10.0
local minDefectArea = 20
local backgroundModel = Image.BackgroundModel.createGaussian(lineScanSensor)

-- Create an edge matcher object. Used to center the object in all images.
local edgeMatcher = Image.Matching.EdgeMatcher.create()
edgeMatcher:setRotationRange(0.2)
local teachRegion = Image.PixelRegion.createRectangle(0, 0, 400, 400);
local edgeMatcherTeached = false

local objectRegionTeach
local teachPose

-- Create a viewer.
local viewer = View.create("viewer2D1")
local prDecoObj = View.PixelRegionDecoration.create()
prDecoObj:setColor(0,255,0, 70)
local prDecoDefect = View.PixelRegionDecoration.create()
prDecoDefect:setColor(255,0,0, 70)
local tDecoTeach = View.TextDecoration.create()
tDecoTeach:setPosition(80, 40)
tDecoTeach:setSize(20)
local tDecoOK = View.TextDecoration.create()
tDecoOK:setPosition(180, 50)
tDecoOK:setColor(0,255,0)
tDecoOK:setSize(30)
local tDecoFail = View.TextDecoration.create()
tDecoFail:setPosition(180, 50)
tDecoFail:setColor(255,0,0)
tDecoFail:setSize(30)

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

-- Teach the background model on specified images.
local function teachBackGroundModel(image)

  -- Teach the edge matcher on the first image. This is performed to obtain the background model ROI.
  if edgeMatcherTeached == false then
    -- Set min downsample factor
    minDsf,_ = matcher:getDownsampleFactorLimits(image)
    edgeMatcher:setDownsampleFactor(minDsf)
    
    teachPose = edgeMatcher:teach(image, teachRegion)
    local edges = edgeMatcher:getModelPoints()
    local edgesPr = Image.PixelRegion.createFromPoints(edges:transform(teachPose), image)
    objectRegionTeach = Image.PixelRegion.getConvexHull(edgesPr)
    if teachPose ~= nil then
      edgeMatcherTeached = true
      backgroundModel:setRegionOfInterest(objectRegionTeach)
    end
  end

  -- Update background model with this new observation
  if edgeMatcherTeached then
    -- Set min downsample factor
    minDsf,_ = matcher:getDownsampleFactorLimits(image)
    edgeMatcher:setDownsampleFactor(minDsf)
  
    local poseTransform = edgeMatcher:match(image)

    -- Transform image to teach position
    local T = Transform.compose(Transform.invert(poseTransform[1]), teachPose)
    local imAtTeach = Image.transform(image, T, "LINEAR")
    viewer:clear()
    local imid = viewer:addImage(imAtTeach)
    viewer:addPixelRegion(objectRegionTeach, prDecoObj, nil, imid)
    viewer:addText("Creating model of object", tDecoTeach, nil, imid)
    viewer:present()

    -- Update the background model
    backgroundModel:add(imAtTeach, objectRegionTeach)
  end
end

-- Compare image with the created background model
local function compareBackGroundModel(image)

  local poseTransform = edgeMatcher:match(image)

  -- Transform image to teach position
  local T = Transform.compose(Transform.invert(poseTransform[1]), teachPose)
  local imAtTeach = Image.transform(image, T, "LINEAR")

  -- Use model to get parts of the image that don't belong
  local fg = backgroundModel:compare(imAtTeach, "ALL", meanThreshold, varianceThreshold)
    
  -- Transform foreground to live image
  local TtoLive = Transform.compose(Transform.invert(teachPose), poseTransform[1])
  local fgLive = Image.PixelRegion.transform(fg, TtoLive, image)

  -- Filter away small regions
  local defectRegions = Image.PixelRegion.findConnected(fgLive, minDefectArea)

  -- Display a visualization of the model
  viewer:clear()
  local imid = viewer:addImage(image)
  viewer:addPixelRegion(defectRegions, prDecoDefect, nil, imid)
  if #defectRegions == 0 then
    viewer:addText("OK!", tDecoOK, nil, imid)
  else
    viewer:addText("Fail!", tDecoFail, nil, imid)
  end
  viewer:present()
end

local function main()
  
  -- Teach object apperance
  print("\nCreating object appearance model")
  for k = 1,5 do
    local im = Image.load('resources/ok/' .. tostring(k-1) .. '.png')
    teachBackGroundModel(im)
    Script.sleep(500)
  end
  print("\nModel created")
  Script.sleep(1000)

  -- Visualize model
  -- Get the model content
  local modelImages = backgroundModel:getModelImages()
  local modelIms = Image.concatenate(modelImages[1], modelImages[2])
  
  viewer:clear()
  local imid = viewer:addImage(modelIms)
  tDecoTeach:setPosition(250, 30)
  viewer:addText("Created object appearance model", tDecoTeach, nil, imid)
  tDecoTeach:setPosition(150, 60)
  viewer:addText("Mean:", tDecoTeach, nil, imid)
  tDecoTeach:setPosition(570, 60)
  viewer:addText("Variance:", tDecoTeach, nil, imid)
  viewer:present()
  Script.sleep(3000)

  -- Detect objects with defects
  print("\nRun detection")
  for k = 1,7 do
    local im = Image.load('resources/mix/' .. tostring(k-1) .. '.png')
    compareBackGroundModel(im)
    Script.sleep(1500)
  end
    
  print("\nApp finished.")
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register("Engine.OnStarted", main)
--End of Function and Event Scope--------------------------------------------------
