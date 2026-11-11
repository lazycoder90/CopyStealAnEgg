--!nonstrict
-- Bootstrap klien. StateController harus Start lebih dulu agar tidak ketinggalan StateInit.

local Controllers = script.Controllers

local StateController = require(Controllers.StateController)
local HUDController = require(Controllers.HUDController)

StateController.Start()
HUDController.Start()
