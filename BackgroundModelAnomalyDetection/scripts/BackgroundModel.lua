
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
local viewer = View.create()
local prDecoObj = View.PixelRegionDecoration.create():setColor(0,255,0, 70)
local prDecoDefect = View.PixelRegionDecoration.create():setColor(255,0,0, 170)
local tDecoTeach = View.TextDecoration.create():setPosition(80, 40):setSize(20)
local tDecoOK = View.TextDecoration.create():setPosition(180, 50):setColor(0,255,0):setSize(30)
local tDecoFail = View.TextDecoration.create():setPosition(180, 50):setColor(255,0,0):setSize(30)

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

---Teach the background model on specified images.
---@param image Image
local function teachBackGroundModel(image)

  -- Teach the edge matcher on the first image. This is performed to obtain the background model ROI.
  if edgeMatcherTeached == false then
    -- Set min downsample factor
    local minDsf,_ = edgeMatcher:getDownsampleFactorLimits(image)
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
    local poseTransform = edgeMatcher:match(image)

    -- Transform image to teach position
    local T = Transform.compose(Transform.invert(poseTransform[1]), teachPose)
    local imAtTeach = Image.transform(image, T, "LINEAR")
    viewer:clear()
    viewer:addImage(imAtTeach)
    viewer:addPixelRegion(objectRegionTeach, prDecoObj)
    viewer:addText("Creating model of object", tDecoTeach)
    viewer:present()

    -- Update the background model
    backgroundModel:add(imAtTeach, objectRegionTeach)
  end
end

---Compare image with the created background model
---@param image Image
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
  viewer:addImage(image)
  viewer:addPixelRegion(defectRegions, prDecoDefect)
  if #defectRegions == 0 then
    viewer:addText("OK!", tDecoOK)
  else
    viewer:addText("Fail!", tDecoFail)
  end
  viewer:present()
end

local function main()

  -- Teach object apperance
  print("\nCreating object appearance model")
  for k = 1,5 do
    print("Teach:",k)
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
  viewer:addImage(modelIms)
  tDecoTeach:setPosition(250, 30)
  viewer:addText("Created object appearance model", tDecoTeach)
  tDecoTeach:setPosition(150, 60)
  viewer:addText("Mean:", tDecoTeach)
  tDecoTeach:setPosition(570, 60)
  viewer:addText("Variance:", tDecoTeach)
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
