--
-- 
-- 
-- @author: Wopster
--

LoadMaterialHolder = {
	modPath = g_currentModDirectory,
	filename = "particleSystems/materialHolder.i3d"
}

function LoadMaterialHolder:loadMap(name)
	local i3dMaterialHolder = Utils.loadSharedI3DFile(LoadMaterialHolder.filename, LoadMaterialHolder.modPath, false, true, false)
	
	local i = 0
	local numOfChildren = getNumOfChildren(i3dMaterialHolder)
	
	for i = 0, numOfChildren - 1 do
		local materialType = getChildAt(i3dMaterialHolder, i)
	
		if materialType ~= nil then		
			MaterialUtil.registerMaterialType(getName(materialType))			
			local numOfFillTypes = getNumOfChildren(materialType)
			
			for f = 0, numOfFillTypes - 1 do
				local fillType = getChildAt(materialType, f)
				
				if fillType ~= 0 then
					local numOfMaterialHolders = getNumOfChildren(fillType)
					
					for h = 0, numOfMaterialHolders - 1 do
						local materialHolder = getChildAt(fillType, h)
						
						if materialHolder ~= 0 then
							MaterialUtil.onCreateMaterial(_, materialHolder)
						end
					end
				end
			end			
		end
	end
	
	delete(i3dMaterialHolder)
end

function LoadMaterialHolder:deleteMap()
	Utils.releaseSharedI3DFile(LoadMaterialHolder.filename, LoadMaterialHolder.modPath, true)
end

function LoadMaterialHolder:mouseEvent(posX, posY, isDown, isUp, button) end
function LoadMaterialHolder:keyEvent(unicode, sym, modifier, isDown) end
function LoadMaterialHolder:update(dt) end
function LoadMaterialHolder:draw() end

addModEventListener(LoadMaterialHolder)