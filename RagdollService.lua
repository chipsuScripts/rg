local RagdollService = {}
-- youtube video link https://www.youtube.com/watch?v=UK7OhZFqN8c

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")


local Remotes = ReplicatedStorage.Remotes
local weld = script.Weld
local RagdollData = require(script.RagdollData)

local alivePlayers = {}

function RagdollService.init()
	-- sets up the characters for each player when they join with the functions provided, and inserts them into the aliveplrs table
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			RagdollService.SetupHumanoid(char:WaitForChild("Humanoid"))
			RagdollService.BuildCollisionParts(char)
			local i = table.find(alivePlayers, plr)
			if i then table.remove(alivePlayers, i) end
			table.insert(alivePlayers,plr)
			char.Humanoid.Died:Connect(function() -- on death 
				RagdollService.RagdollCharacter(char)
				RagdollService.DropItems(char)
				print(alivePlayers,#alivePlayers)
			
			end)
		end)
		plr:LoadCharacter()
	end)
	
	Players.PlayerRemoving:Connect(function(plr) 
		local i = table.find(alivePlayers, plr)
		if i then table.remove(alivePlayers, i) end
		if #alivePlayers <= 0 then -- if the player leaves and he was the last one alive, end the game.
			Remotes.DeadUI:FireAllClients("GameOver") -- the deadUi handles ui on the client, for gameover it will basically play a outro then show a voting screen where plrs can vote to play again.
			Remotes.VotingInProgress:Fire(true)
		end
	end)
	
	Remotes.ReviveProduct.Event:Connect(function(data) -- fired from a productservice serverscript, when someone successfully purchases a revive dev product
		if type(data) ~= "table" then -- safety
			warn("Invalid revive event data") 
			return
		end
		local action = data.action
		local players = data.players

		if action == "Revive" then -- if they bought revive urself, then the action will be Revive , if they bought revive all dev product, itll be reviveAll
			local plr = players[1]
			if plr and plr.Character then
				RagdollService.RespawnChar(plr.Character)
			end

		elseif action == "ReviveAll" then
			for _, plr in ipairs(players) do
				if plr.Character then
					RagdollService.RespawnChar(plr.Character)
				end
			end
		end
	end)
	
	
	
end

function RagdollService.DropItems(char: Model) -- just drops the items from the plr ( called when they die )
	for _,v in pairs(char:GetChildren()) do
		if v:IsA("Tool") then
			v.Parent = workspace
		end
	end
	local plr = Players:GetPlayerFromCharacter(char) 
	for _,v in pairs(plr.Backpack:GetChildren()) do -- checking backpack too incase they weren't holding it
		if v:IsA("Tool") then
			v.Parent = workspace
		end
	end
end

function RagdollService.SetupHumanoid(Hum : Humanoid) 
	Hum.BreakJointsOnDeath = false -- disables the joints breaking on death so we can do a ragdoll
	Hum.RequiresNeck = false 
end

function RagdollService.BuildCollisionParts(char) -- basically clone every bodypart inside the character and make it invis noncollideable..., and weld it to the main part
	for _,v in pairs(char:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			local p : BasePart = v:Clone()
			p.Parent = v
			p.CanCollide = false
			p.Massless = true
			p.Size = Vector3.one
			p.Name = "Collide"
			p.Transparency = 1
			p:ClearAllChildren()
			
			
			local weldClone = weld:Clone()
			weldClone.Parent = p
			weldClone.Part0 = v
			weldClone.Part1 = p
			
		end
	end
end


function RagdollService.EnableMotor6D(char: Model,enabled : boolean) -- looping in everything in the char, and enabling(or disable) it (motor6d) so we can do a nice ragdoll
	for _,v in pairs(char:GetDescendants()) do
		if v.Name == "Handle" or v.Name == "RootJoint" or v.Name == "Neck" then continue end
		if v:IsA("Motor6D") then v.Enabled = enabled end
	end
end

function RagdollService.DestroyJoints(char: Model) -- clear up the char (called on death)
	for _,v in pairs(char:GetDescendants()) do
		if v.Name == "RAGDOLL_ATTACHMENT" or v.Name == "RAGDOLL_CONSTRAINT" then v:Destroy() end
		
		if not v:IsA("BasePart") or v:FindFirstAncestorOfClass("Accessory") or v.Name == "Torso" or v.Name == "Head" then continue end
		
	end
end




function RagdollService.EnableCollsioinParts(char: Model,enabled)
	for _,v in pairs(char:GetChildren()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.CanCollide = not enabled
			v.Collide.CanCollide = enabled
		end
	end
end

function RagdollService.RespawnChar(char: Model) -- just revives the plr, addes them to aliveplrs, fires some signals to the client
	
	local plr = Players:GetPlayerFromCharacter(char)
	local deathPosition = char.HumanoidRootPart.Position
	Remotes.DeadUI:FireClient(plr,"Hide")
	char:Destroy()
	local i = table.find(alivePlayers, plr)
	if i then table.remove(alivePlayers, i) end
	plr:LoadCharacter()
	table.insert(alivePlayers,plr)
	local plrGui = plr:WaitForChild("PlayerGui")
	local deadGui = plrGui:WaitForChild("DeadGUI")
	deadGui.SpectateFrame.Revive:SetAttribute("productName","Revive") -- since the gui restarts on death, my ui script wont set the button "revive" a target productName, so this is to make sure that it's updated.
	deadGui.DeathFrame.EndingFrame.ReviveAll:SetAttribute("productName","ReviveAll")-- same here

	local newChar = plr.Character
	
	local newHrp = newChar:FindFirstChild()("HumanoidRootPart")
	local newHum = newChar:FindFirstChild("Humanoid")
	local Animator = newHum:FindFirstChild("Animator",2)
	if Animator and newHrp and newHum then
		task.wait(0.05)
		local anim = Animator:LoadAnimation(script.Revive)
		anim:Play()
	end
	newHrp.CFrame = CFrame.new(deathPosition)
	
	
end


function RagdollService.BuildJoints(char: Model) -- ball socket constraint to make realistic ragdoll ,here we are making 2 attachments ,
	local hrp = char:FindFirstChild("HumanoidRootPart")
	
	for _,v in pairs(char:GetDescendants()) do
		if not v:IsA("BasePart") or v:FindFirstAncestorOfClass("Accessory") 
			or v.Name == "Handle" or v.Name == "Torso" or v.Name == "HumanoidRootPart" then continue end
		
		if not RagdollData[v.Name] then continue end
		
		local a0:Attachment,a1:Attachment = Instance.new("Attachment"),Instance.new("Attachment")
		local joint = Instance.new("BallSocketConstraint")
		
		a0.Name = "RAGDOLL_ATTACHMENT"
		a0.Parent = v  a0 is going to be inside the bodypart 
		a0.CFrame = RagdollData[v.Name].CFrame[2] 
		
		a1.Name = "RAGDOLL_ATTACHMENT"
		a1.Parent = hrp
		a1.CFrame = RagdollData[v.Name].CFrame[1]
		
		joint.Name = "RAGDOLL_CONSTRAINT"
		joint.Parent = v
		joint.Attachment0 = a0
		joint.Attachment1 = a1
		v.Massless = true
		
	end
	
end

function RagdollService.RagdollCharacter(char: Model)
	
	local plr = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	
	if not hrp then return end
	RagdollService.EnableMotor6D(char,false)
	RagdollService.BuildJoints(char)
	RagdollService.EnableCollsioinParts(char,true)
	RagdollService.CreateProximityPrompt(char) 
	local highlight = script.DeadHighlight:Clone() -- clone not new for performance 
	highlight.Parent = char 
	highlight.Enabled = true
	
	local i = table.find(alivePlayers,plr)
	
	table.remove(alivePlayers,i)
	
	if plr then
		if #alivePlayers <= 0 then
			Remotes.DeadUI:FireAllClients("GameOver")
			Remotes.VotingInProgress:Fire(true)
		else
			print("Show For"..plr.Name)
			Remotes.Ragdoll:Fire(plr,"Ragdoll")
			Remotes.DeadUI:FireClient(plr,"Show")
			Remotes.PlrDown:FireAllClients("plrDown",plr.Name)
		end
	else
		hrp:SetNetworkOwner(nil)
		hum.AutoRotate = false
		hum.PlatformStand = true
	end
end

function RagdollService.CreateProximityPrompt(char: Model) -- addes a proximity so plrs can revive the downed plr
	
	local client = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChild("Humanoid")
	
	if hum.Health > 0 or hum:GetState() ~= Enum.HumanoidStateType.Dead then return end
	
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = char.Name
	prompt.HoldDuration = 4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = char.HumanoidRootPart
	prompt.Triggered:Connect(function(player)
		print(player.Name .."Tried to Revive".. client.Name)
		local plrChar = player.Character or player.CharacterAdded:Wait()
		local medkit = plrChar:FindFirstChild("MEDKIT")
		if medkit and medkit:HasTag("Medkit") then
			local anim = plrChar.Humanoid.Animator:LoadAnimation(medkit.Heal)
			anim:Play()
			Debris:AddItem(medkit,0.1)
			RagdollService.RespawnChar(char)
		end
	end)
end


function RagdollService.UnRagdollCharacter(char: Model) -- could be used if a custom health tracking system is being used, instead of loading the character again just unragdoll them

	local plr = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if not hrp then return end
	RagdollService.EnableMotor6D(char,false)
	RagdollService.BuildJoints(char)
	RagdollService.EnableCollsioinParts(char,true)

	if plr then
		Remotes.Ragdoll:Fire(plr,"UnRagdoll")
	else
		hrp:SetNetworkOwner(nil)
		if hum:Getstate() == Enum.HumanoidStateType.Dead then return end
		hum.PlatformStand = false
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	RagdollService.DestroyJoints(char)
	RagdollService.EnableMotor6D(char,true)
	RagdollService.EnableCollsioinParts(char,false)
	
	hum.AutoRotate = true
	
end





return RagdollService




