--
-- playerInRangeTool
-- 
-- @author:    	Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- @history:	v1.0 - 2015-06-24 - Initial implementation
-- 				v1.1 - 2016-01-08 - Update to how it shows inputbinding
--

playerInRangeTool = {};
playerInRangeTool.modName = g_currentModName;
playerInRangeTool.modPath = g_currentModDirectory;

playerInRangeTool.TRANSLATIONS = {};
playerInRangeTool.TRANSLATIONS["en"] = "Press %s to";
playerInRangeTool.TRANSLATIONS["de"] = "Drücke %s um";

addModEventListener(playerInRangeTool);

function playerInRangeTool:loadMap()
	self.playerMinDistance = 2;
	self.scriptVersion = 1.11;
	
	if g_currentMission.playerInRangeTool == nil then
		g_currentMission.playerInRangeTool = self;
		g_currentMission.playerInRangeExtras = {};
		
		playerInRangeTool.loadHud(self);
	else
		if g_currentMission.playerInRangeTool.scriptVersion < self.scriptVersion then
			if g_currentMission.playerInRangeTool ~= self then
				print("playerInRangeTool - Notice: playerInRangeTool v" .. g_currentMission.playerInRangeTool.scriptVersion .. " have been replaced with a newer v" .. self.scriptVersion .. " from the mod " .. playerInRangeTool.modName);
				
				if g_currentMission.playerInRangeTool.infoArrow ~= nil then
					g_currentMission.playerInRangeTool.infoArrow:delete();
					g_currentMission.playerInRangeTool.infoArrow = nil;
				end;
				
				playerInRangeTool.loadHud(self);
				g_currentMission.playerInRangeTool = self;
			end;
		end;
	end;
end;

function playerInRangeTool:loadHud()
	local filename = Utils.getFilename("shared/hud_info_arrow.dds", playerInRangeTool.modPath);
	
	if fileExists(filename) then
		local width, height = getScreenModeInfo(getScreenMode());
		self.infoArrow = Overlay:new("hud_info_arrow", filename, 0.5, 0.5, 70 / width, 70 / height);
	end;
end;

function playerInRangeTool:deleteMap()
	if g_currentMission.playerInRangeTool ~= nil and g_currentMission.playerInRangeTool == self then
		g_currentMission.playerInRangeExtras = nil;
		g_currentMission.playerInRangeTool = nil;
	end;
	
	if self.infoArrow ~= nil then
		self.infoArrow:delete();
		self.infoArrow = nil;
	end;
end;

function playerInRangeTool:mouseEvent(posX, posY, isDown, isUp, button)
end;

function playerInRangeTool:keyEvent(unicode, sym, modifier, isDown)
end;

function playerInRangeTool:update(dt)
	if g_currentMission.playerInRangeTool ~= nil and g_currentMission.playerInRangeTool == self then
		if g_currentMission.player ~= nil then
			local tableEmpty = true;
			
			if g_currentMission.player.isControlled and g_currentMission.player.isEntered then
				if g_currentMission.player.activeTool == nil then
					local px, py, pz = getWorldTranslation(g_currentMission.player.rootNode);
					
					for _, e in pairs({g_currentMission.vehicles, g_currentMission.playerInRangeExtras}) do
						for i, vehicle in pairs(e) do
							local playerInRangeTool = nil;
							
							-- only check distance on mods that are set for it for now.
							if vehicle.playerInRangeTool ~= nil then
								playerInRangeTool = vehicle.playerInRangeTool;
							end;
							
							if playerInRangeTool ~= nil then
								for locationId, v in ipairs(playerInRangeTool) do
									if v.node ~= nil then
										local x, y, z = getWorldTranslation(v.node);
										local distance = Utils.vector3Length(x - px, y - py, z - pz);
										local update = false;
										local playerDistance = Utils.getNoNil(v.playerDistance, self.playerMinDistance);
										
										if distance < playerDistance then
											if g_currentMission.player.closestTool == nil then
												update = true;
											else
												if g_currentMission.player.closestToolDistance > distance then
													update = true;
												end;
												if g_currentMission.player.closestTool == vehicle and g_currentMission.player.closestToolLocationId == locationId then
													update = true;
												end;
											end;
											
											if update then
												g_currentMission.player.closestTool = vehicle;
												g_currentMission.player.closestToolLocationId = locationId;
												g_currentMission.player.closestToolDistance = distance;
											end;
											
											tableEmpty = false;
										end;
									end;
								end;
							end;
						end;
					end;
				end;
			end;
			
			if tableEmpty then
				if g_currentMission.player.closestTool ~= nil then
					g_currentMission.player.closestTool = nil;
					g_currentMission.player.closestToolLocationId = nil;
					g_currentMission.player.closestToolDistance = nil;
				end;
			end;
			
			
			if g_currentMission.player.closestTool ~= nil then
				if g_currentMission.controlPlayer and g_gui.currentGui == nil and not g_currentMission.isPlayerFrozen then
					local toolSelf = g_currentMission.player.closestTool;
					local closestTool = toolSelf.playerInRangeTool[g_currentMission.player.closestToolLocationId];
					local tool = closestTool.interactiveData;
					
					if tool ~= nil and not tool.stopShowing then
						local txt = tool.text1;
						if tool.boolName ~= nil then
							if tool.text2 ~= nil and toolSelf[tool.boolName] then
								txt = tool.text2;
							end;
						end;
						
						local showArrow = false;
						local offset = {0, 0, 0};
						
						if tool.offset ~= nil then
							offset = tool.offset;
						end;
						
						local worldX, worldY, worldZ = localToWorld(closestTool.node, offset[1], offset[2], offset[3]);
						local x, y, z = project(worldX, worldY, worldZ);
						
						if x < 0.95 and y < 0.95 and z < 1 and x > 0.05 and y > 0.05 and z > 0 then
							local binding = Utils.getNoNil(tool.inputbinding, InputBinding.IMPLEMENT_EXTRA2);
							local keyNames = InputBinding.getKeyNamesOfDigitalAction(binding);
							local langTxt = Utils.getNoNil(playerInRangeTool.TRANSLATIONS[g_languageShort], playerInRangeTool.TRANSLATIONS["en"]);
							
							if g_settingsGamepadHelpEnabled then
								keyNames = Utils.getNoNil(InputBinding.getDigitalActionGamepadButtonNames(binding), keyNames);
							end;
							
							setTextAlignment(RenderText.ALIGN_CENTER);
							setTextColor(1, 1, 1, 1);
							renderText(x, y + 0.01, 0.017, string.format(langTxt, keyNames));
							renderText(x, y - 0.02, 0.017, txt);
							setTextAlignment(RenderText.ALIGN_LEFT);
							
							if InputBinding.hasEvent(binding) then
								if tool.boolName ~= nil then
									toolSelf[tool.functionName](toolSelf, not toolSelf[tool.boolName]);
								else
									toolSelf[tool.functionName](toolSelf);
								end;
							end;
						else
							if self.infoArrow ~= nil then
								local playerNode = g_currentMission.player.graphicsRootNode;
								local target = {worldX, worldY, worldZ};
								local player = {getWorldTranslation(playerNode)};
								local aim = {localToWorld(playerNode, 0, 0, -0.1)};
								local playerRotation = math.deg(math.atan2(player[3] - aim[3], player[1] -  aim[1]) - math.atan2(target[3] - aim[3], target[1] -  aim[1]));
								
								if x > 0.05 and x < 0.95 and (playerRotation < -90 or playerRotation > 90) then
									x = 0.5;
									y = Utils.clamp(y, 0.03, 0.90);
								else
									y = 0.5;
									
									if playerRotation < 180 and playerRotation > 0 or playerRotation < -180 and playerRotation > -360 then
										x = 0.94;
									else
										x = 0.02;
									end;
								end;
								
								if (self.infoArrow.x ~= x or self.infoArrow.y ~= y) then
									self.infoArrow:setPosition(x, y);
								end;
								
								showArrow = true;
							end;
						end;
						
						if self.infoArrow ~= nil then
							if self.infoArrow.visible ~= showArrow then
								self.infoArrow:setIsVisible(showArrow);
							end;
						end;
					end;
				end;
			end;
		end;
	end;
end;

function playerInRangeTool:draw()
	if g_currentMission.playerInRangeTool ~= nil and g_currentMission.playerInRangeTool == self then
		if g_currentMission.player.closestTool ~= nil then
			if g_currentMission.controlPlayer and g_gui.currentGui == nil and not g_currentMission.isPlayerFrozen then
				if self.infoArrow ~= nil then
					self.infoArrow:render();
				end;
			end;
		end;
	end;
end;