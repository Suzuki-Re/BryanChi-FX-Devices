-------------General Functions ------------------------------

-- @noindex
r = reaper

---General functions list

---@param str string
function GetFileExtension(str)
    return str:match("^.+(%..+)$")
end
function InvisiBtn (ctx, x, y, str, w, h )  
    if x and y then 
        r.ImGui_SetCursorScreenPos(ctx, x,y)
    end
    local rv = r.ImGui_InvisibleButton(ctx, str,w,h or w)


    return rv
end

function ThirdPartyDeps()
    local ultraschall_path = reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua"
    local readrum_machine = reaper.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/Suzuki_ReaDrum_Machine_Instruments_Rack.lua"

    local version = tonumber (string.sub( reaper.GetAppVersion() ,  0, 4))
    --reaper.ShowConsoleMsg((version))

    local fx_browser_path
    local n,arch = reaper.GetAppVersion():match("(.+)/(.+)")
    local fx_browser_v6_path
    
    if n:match("^7%.") then
        fx_browser = reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"
        fx_browser_reapack = 'sexan fx browser parser v7' 
    else
        fx_browser= reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_Parser.lua"  
        fx_browser_v6_path = reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_Parser.lua"
       fx_browser_reapack = 'sexan fx browser parser v6'

    end
    --local fx_browser_v6_path = reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_Parser.lua"
    --local fx_browser_v7_path = reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"
    
    local reapack_process
    local repos = {
      {name = "Sexan_Scripts", url = 'https://github.com/GoranKovac/ReaScripts/raw/master/index.xml'},
      {name = "Ultraschall-API", url = 'https://github.com/Ultraschall/ultraschall-lua-api-for-reaper/raw/master/ultraschall_api_index.xml'},
      {name = "Suzuki Scripts", url = 'https://github.com/Suzuki-Re/Suzuki-Scripts/raw/master/index.xml'},
    }
    
    for i = 1, #repos do
      local retinfo, url, enabled, autoInstall = reaper.ReaPack_GetRepositoryInfo( repos[i].name )
      if not retinfo then
        retval, error = reaper.ReaPack_AddSetRepository( repos[i].name, repos[i].url, true, 0 )
        reapack_process = true
      end
    end
   
    -- ADD NEEDED REPOSITORIES
    if reapack_process then
      reaper.ShowMessageBox("Added Third-Party ReaPack Repositories", "ADDING REPACK REPOSITORIES", 0)
      reaper.ReaPack_ProcessQueue(true)
      reapack_process = nil
    end
    
    if not reapack_process then
      -- ULTRASCHALL
      if reaper.file_exists(ultraschall_path) then
          dofile(ultraschall_path)
      else
          reaper.ShowMessageBox("Ultraschall API is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
          reaper.ReaPack_BrowsePackages('ultraschall')
          return 'error ultraschall'
      end
      -- FX BROWSER
      if reaper.file_exists(fx_browser) then
          dofile(fx_browser)
      else
         reaper.ShowMessageBox("Sexan FX BROWSER is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
         reaper.ReaPack_BrowsePackages(fx_browser_reapack)
         return 'error Sexan FX BROWSER'
      end
      -- ReaDrum Machine
      if reaper.file_exists(readrum_machine) then
        local found_readrum_machine = true
      else
      reaper.ShowMessageBox("ReaDrum Machine is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      reaper.ReaPack_BrowsePackages('readrum machine')
      return 'error Suzuki ReaDrum Machine'
      end
    end
end
function msg(a)
    r.ShowConsoleMsg(a)
end

function AddRandomSample(howmany, SampleSlot)
    
    for I = 1, howmany , 1 do 
        local filename = MatchedFiles[math.random(1, #MatchedFiles)]
        local rv = InsertSample(filename)
        local TB
        if SampleSlot then 
            TB= Added[SampleSlot]
        else
            table.insert(Added, {})
            TB = Added[#Added]
        end
        TB.it, TB.tk, TB.src = GetSelectedMediaItemInfo(0)
        TB.KeyWord = TB.KeyWord or  {}
        Add_KeyWord_To_Itm_tb(TB.KeyWord, #Added)
        Match_Itm_Len_and_Src_Len(TB.src, TB.it, TB.tk)
    end

end





function SwapSample( Itm,  MatchedFiles)
    if #MatchedFiles <=1 then return end 

    local filename = MatchedFiles[math.random(1, #MatchedFiles)]
    r.BR_SetTakeSourceFromFile(Itm.tk, filename, true )
    Itm.src = r.GetMediaItemTake_Source(Itm.tk)
    table.insert(BUILD_PEAK, Itm.src )
    --BUILD_PEAK = r.PCM_Source_BuildPeaks(v.src, 0)
    local nm = Remove_Dir_path (filename)
    retval,  stringNeedBig = r.GetSetMediaItemTakeInfo_String(Itm.tk, 'P_NAME', nm, true )
    Match_Itm_Len_and_Src_Len(Itm.src, Itm.it, Itm.tk)
    r.UpdateArrange()

end


function Add_KeyWord_To_Itm_tb(keywordTB, idx)
    Added[idx].KeyWord={}
    if SearchTxt~='' then 
        table.insert(Added[idx].KeyWord, SearchTxt)
    end
    for i, v in ipairs(KeyWord) do 
        if not FindStringInTable(Added[idx].KeyWord, v ) then 
            table.insert(Added[idx].KeyWord, v)
        end 
    end 
end

function Delete_All_FXD_AnalyzerFX(trk)
    local  ct = r.TrackFX_GetCount(trk)
    for i= 0 , ct,  1 do 
        local rv, name =  r.TrackFX_GetFXName(trk, i )

        if FindStringInTable(FX_To_Delete_At_Close, name) then 
            r.TrackFX_Delete(trk, i )
        end
    end 
end

------------------------------------------------------------------------------
function BuildFXTree_item(tr, fxid, scale, oldscale)
    local tr = tr or LT_Track 
    local retval, buf = reaper.TrackFX_GetFXName( tr, fxid )
    local ccok, container_count = reaper.TrackFX_GetNamedConfigParm( tr, fxid, 'container_count')

    local ret = {
        fxname = buf,
        isopen = reaper.TrackFX_GetOpen( tr, fxid ),
        GUID = reaper.TrackFX_GetFXGUID( tr, fxid ),
        addr_fxid = fxid,
        scale = oldscale
      }

    if ccok then  -- if fx in container is a container
      ret.children = { }
      local newscale = scale * (tonumber(container_count)+1)

      for child = 1, tonumber(container_count) do
        ret.children[child] = BuildFXTree_item(tr, fxid + scale * child, newscale, scale)
      end
    end
    return ret
end
--------------------------------------------------------------------------
function BuildFXTree(tr)
    -- table with referencing ID tree
    local tr = tr or LT_Track 
    if tr then 
        tree = {}
        local cnt = reaper.TrackFX_GetCount(tr)
        for i = 1, cnt do
            tree[i] = BuildFXTree_item(tr, 0x2000000+i, cnt+1, cnt+1)
        end
        return tree
    end
end

function Check_If_Has_Children_Prioritize_Empty_Container(TB)
    local Candidate
    for i, v in ipairs( TB)  do 
        if v.children then     
            if v.children[1] then --if container not empty 
                Candidate =  v.children 
            elseif not v.children[1] then   -- if container empty

                local Final = v.children ~=nil and 'children' or 'candidate'
                return v.children or Candidate
            end
        end
    end
    if  Candidate then 
        return  Candidate
    end
end

local tr = reaper.GetSelectedTrack(0,0)
TREE = BuildFXTree(LT_Track or tr)

function EndUndoBlock(str)
    r.Undo_EndBlock("ReaDrum Machine: " .. str, -1)
  end

function Curve_3pt_Bezier(startX,startY,controlX,controlY,endX,endY)
    local X , Y = {}, {}
    for t = 0, 1, 0.1 do

        local x = (1 - t) * (1 - t) * startX + 2 * (1 - t) * t * controlX + t * t * endX
        local y = (1 - t) * (1 - t) * startY + 2 * (1 - t) * t * controlY + t * t * endY
        table.insert(X, x)
        table.insert(Y, y)
    end
    return X,Y
end


function GetTrkSavedInfo(str, track, type  )

    if type=='str' then 
        local o = select(2, r.GetSetMediaTrackInfo_String(track or LT_Track , 'P_EXT: '..str, '', false))
        if o == '' then o = nil end 
        return o
    else
        return tonumber( select(2, r.GetSetMediaTrackInfo_String(track or LT_Track , 'P_EXT: '..str, '', false)))
    end
end

function getProjSavedInfo(str, type  )

    if type=='str' then 
        return select(2, r.GetProjExtState(0, 'FX Devices', str ))
    else
        return tonumber(select(2, r.GetProjExtState(0, 'FX Devices', str ))) 
    end
end



function Normalize_Val (V1, V2, ActualV ,  Bipolar)

    local Range = math.abs( (math.max(V1, V2) - math.min(V1, V2)) )
    
    local NormV = (math.min(V1, V2)+ Range - ActualV) / Range

    if Bipolar  then 
        return  -1 + (NormV  )* 2
    else 
        return NormV
    end
end


---@param FX_Name string
function ChangeFX_Name(FX_Name)
    if FX_Name then
        local FX_Name = FX_Name:gsub("%w+%:%s+",
            {
                ['AU: '] = "",
                ['JS: '] = "",
                ['VST: '] = "",
                ['VSTi: '] = "",
                ['VST3: '] = '',
                ['VST3i: '] = "",
                ['CLAP: '] = "",
                ['CLAPi: '] = ""
            })
        local FX_Name = FX_Name:gsub('[%:%[%]%/]', "_")
        return FX_Name
    end
end

function AddMacroJSFX()
    local MacroGetLT_Track = r.GetLastTouchedTrack()
    MacrosJSFXExist = r.TrackFX_AddByName(MacroGetLT_Track, 'FXD Macros', 0, 0)
    if MacrosJSFXExist == -1 then
        r.TrackFX_AddByName(MacroGetLT_Track, 'FXD Macros', 0, -1000)
        r.TrackFX_Show(MacroGetLT_Track, 0, 2)
        return false
    else
        return true
    end
end

function GetLTParam()
    LT_Track = r.GetLastTouchedTrack()
    retval, LT_Prm_TrackNum, LT_FXNum, LT_ParamNum = r.GetLastTouchedFX()
    --GetTrack_LT_Track = r.GetTrack(0,LT_TrackNum)

    if LT_Track ~= nil then
        retval, LT_FXName = r.TrackFX_GetFXName(LT_Track, LT_FXNum)
        retval, LT_ParamName = r.TrackFX_GetParamName(LT_Track, LT_FXNum, LT_ParamNum)
    end
end

function GetLT_FX_Num()
    retval, LT_Prm_TrackNum, LT_FX_Number, LT_ParamNum = r.GetLastTouchedFX()
    LT_Track = r.GetLastTouchedTrack()
end

---@param enable boolean
---@param title string
function MouseCursorBusy(enable, title)
    mx, my = r.GetMousePosition()

    local hwnd = r.JS_Window_FindTop(title, true)
    local hwnd = r.JS_Window_FromPoint(mx, my)

    if enable then -- set cursor to hourglass
        r.JS_Mouse_SetCursor(Invisi_Cursor)
        -- block app from changing mouse cursor
        r.JS_WindowMessage_Intercept(hwnd, "WM_SETCURSOR", false)
    else -- set cursor to arrow
        r.JS_Mouse_SetCursor(r.JS_Mouse_LoadCursor(32512))
        -- allow app to change mouse cursor
    end
end

function ConcatPath(...)
    -- Get system dependent path separator
    local sep = package.config:sub(1, 1)
    return table.concat({ ... }, sep)
end

---@param Input number
---@param Min number
---@param Max number
---@return number
function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

---TODO do we need this function? It’s unused
---@param str string|number|nil
function ToNum(str)
    str = tonumber(str)
end

---@generic T
---@param v? T
---@return boolean
function toggle(v)
    if v then v = false else v = true end
    return v
end

---@param str string
function get_aftr_Equal(str)
    if str then
        local o = str:sub((str:find('=') or -2) + 2)
        if o == '' or o == ' ' then o = nil end
        return o
    end
end



---@param Str string
---@param Id string
---@param Fx_P integer
---@param Type? "Num"|"Bool"
---@param untilwhere? integer
function RecallInfo(Str, Id, Fx_P, Type, untilwhere)
    if Str then
        local Out, LineChange
        local ID = Fx_P .. '%. ' .. Id .. ' = '
        local Start, End = Str:find(ID)
        if untilwhere then
            LineChange = Str:find(untilwhere, Start)
        else
            LineChange = Str:find('\n', Start)
        end
        if End and Str and LineChange then
            if Type == 'Num' then
                Out = tonumber(string.sub(Str, End + 1, LineChange - 1))
            elseif Type == 'Bool' then
                if string.sub(Str, End + 1, LineChange - 1) == 'true' then Out = true else Out = false end
            else
                Out = string.sub(Str, End + 1, LineChange - 1)
            end
        end
        if Out == '' then Out = nil end
        return Out
    end
end

---@param Str string
---@param ID string
---@param Type? "Num"|"Bool"
---@param untilwhere? integer
function RecallGlobInfo(Str, ID, Type, untilwhere)
    if Str then
        local Out, LineChange
        local Start, End = Str:find(ID)

        if untilwhere then
            LineChange = Str:find(untilwhere, Start)
        else
            LineChange = Str:find('\n', Start)
        end
        if End and Str and LineChange then
            if Type == 'Num' then
                Out = tonumber(string.sub(Str, End + 1, LineChange - 1))
            elseif Type == 'Bool' then
                if string.sub(Str, End + 1, LineChange - 1) == 'true' then Out = true else Out = false end
            else
                Out = string.sub(Str, End + 1, LineChange - 1)
            end
        end
        if Out == '' then Out = nil end
        return Out
    end
end

---@param Str string|nil
---@param Id string
---@param Fx_P integer
---@param Type? "Num"|"Bool"
---@return string[]|nil
function RecallIntoTable(Str, Id, Fx_P, Type)
    if Str then
        local _, End = Str:find(Id)
        local T = {}
        while End do
            local NextLine = Str:find('\n', End)
            local EndPos
            local NextSep = Str:find('|', End)
            if NextSep and NextLine then
                if NextSep > NextLine then
                    End = nil
                else
                    if Type == 'Num' then
                        table.insert(T, tonumber(Str:sub(End + 1, NextSep - 1)))
                    else
                        table.insert(T, Str:sub(End + 1, NextSep - 1))
                    end

                    _, NewEnd = Str:find('|%d+=', End + 1)
                    if NewEnd then
                        if NewEnd > NextLine then End = nil else End = NewEnd end
                    else
                        End = nil
                    end
                end
            else
                End = nil
            end
        end
        if T[1] then return T end
    end
end

---@param str string|nil
function get_aftr_Equal_bool(str)
    if str then
        local o = str:sub(str:find('=') + 2) ---@type string |boolean | nil
        if o == '' or o == ' ' or 0 == 'nil' then
            o = nil
        elseif o == 'true' then
            o = true
        elseif o == 'false' then
            o = false
        else
            o = nil
        end
        return o
    end
end

---@param str string|nil
function get_aftr_Equal_Num(str, Title)
    if str then
        if not Title then 
            if str:find('=') then
                return tonumber(str:sub(str:find('=') + 2))
            end
        else 
            if str:find(Title) then
                return tonumber(str:sub(str:find(Title) + 2))
            end
        end
    else
        return nil
    end
end

---@param str string
function OnlyNum(str)
    return tonumber(str:gsub('[%D%.]', ''))
end

---@param filename string
---@return string[]
function get_lines(filename)
    local lines = {}
    -- io.lines returns an iterator, so we need to manually unpack it into an array
    for line in io.lines(filename) do
        lines[#lines + 1] = line
    end
    return lines
end

---@generic T
---@generic Index
---@param Table table<Index, T>
---@param Pos1 Index
---@param Pos2 Index
---@return table<Index,T> Table
function TableSwap(Table, Pos1, Pos2)
    Table[Pos1], Table[Pos2] = Table[Pos2], Table[Pos1]
    return Table
end

---@generic T
---@generic Index
---@param tab table<Index, T>
---@param el T
---@return Index|nil
function tablefind(tab, el)
    if tab then
        for index, value in pairs(tab) do
            if value == el then
                return index
            end
        end
    end
end

---@param FxGUID string
function GetProjExt_FxNameNum(FxGUID)
    local PrmCount
    rv, PrmCount = r.GetProjExtState(0, 'FX Devices', 'Prm Count' .. FxGUID)
    if PrmCount ~= '' then FX.Prm.Count[FxGUID] = tonumber(PrmCount) end
    FX[FxGUID] = FX[FxGUID] or {}

    if rv ~= 0 then
        for P = 1, FX.Prm.Count[FxGUID], 1 do
            FX[FxGUID][P] = FX[FxGUID][P] or {}
            local FP = FX[FxGUID][P]
            if FP then
                _, FP.Name = r.GetProjExtState(0, 'FX Devices', 'FX' .. P .. 'Name' .. FxGUID)
                _, FP.Num = r.GetProjExtState(0, 'FX Devices', 'FX' .. P .. 'Num' .. FxGUID); FP.Num = tonumber(FP.Num)
            end
        end
    end
end

---@param FX_Idx integer
---@param Target_FX_Idx integer
---@param FX_Name string
function SyncAnalyzerPinWithFX(FX_Idx, Target_FX_Idx, FX_Name)
    -- input --
    local Target_L, _ = r.TrackFX_GetPinMappings(LT_Track, Target_FX_Idx, 0, 0) -- L chan
    local Target_R, _ = r.TrackFX_GetPinMappings(LT_Track, Target_FX_Idx, 0, 1) -- R chan
    local L, _ = r.TrackFX_GetPinMappings(LT_Track, FX_Idx, 0, 0)               -- L chan
    local R, _ = r.TrackFX_GetPinMappings(LT_Track, FX_Idx, 0, 1)               -- R chan


    if L ~= Target_L then
        if not FX_Name then _, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx) end

        r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 0, 0, Target_L, 0)


        if FX_Name:find('JS: FXD ReSpectrum') then
            for i = 2, 16, 1 do
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 0, i, 0, 0)
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 1, i, 0, 0)
            end
        end


        if FX_Name == 'JS: FXD Split to 4 channels' then
            r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 1, 2, Target_R * 2, 0)
        elseif FX_Name == 'JS: FXD Gain Reduction Scope' then
            r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 0, 2, Target_R * 2, 0)
        end
    end
    if R ~= Target_R then
        r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 0, 1, Target_R, 0)
        if FX_Name == 'JS: FXD Split to 4 channels' then
            r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 1, 3, Target_R * 4, 0)
        elseif FX_Name:find('FXD Gain Reduction Scope') then
            r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 0, 3, Target_R * 4, 0)
        end
    end



    -- output --
    local Target_L, _ = r.TrackFX_GetPinMappings(LT_Track, Target_FX_Idx, 1, 0) -- L chan
    local Target_R, _ = r.TrackFX_GetPinMappings(LT_Track, Target_FX_Idx, 1, 1) -- R chan
    local L, _ = r.TrackFX_GetPinMappings(LT_Track, FX_Idx, 1, 0)               -- L chan
    local R, _ = r.TrackFX_GetPinMappings(LT_Track, FX_Idx, 1, 1)               -- R chan
    if L ~= Target_L then
        r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 1, 0, Target_L, 0)
    end
    if R ~= Target_R then
        r.TrackFX_SetPinMappings(LT_Track, FX_Idx, 1, 1, Target_R, 0)
    end
end

---TODO I think Position is meant to be used as «instantiate» variable, is this the intent?
---@param track MediaTrack
---@param fx_name string
---@param Position integer
function AddFX_HideWindow(track, fx_name, Position)
    local val = r.SNM_GetIntConfigVar("fxfloat_focus", 0)
    if val & 4 == 0 then
        r.TrackFX_AddByName(track, fx_name, 0, Position)   -- add fx
    else
        r.SNM_SetIntConfigVar("fxfloat_focus", val & (~4)) -- temporarily disable Auto-float newly created FX windows
        r.TrackFX_AddByName(track, fx_name, 0, Position)   -- add fx
        r.SNM_SetIntConfigVar("fxfloat_focus", val|4)      -- re-enable Auto-float
    end
end

---@param FX_Idx integer
---@return integer|nil
function ToggleCollapseAll(FX_Idx)
    -- check if all are collapsed
    local All_Collapsed
    for i = 0, Sel_Track_FX_Count - 1, 1 do
        if not FX[FXGUID[i]].Collapse then All_Collapsed = false end
    end
    if All_Collapsed == false then
        for i = 0, Sel_Track_FX_Count - 1, 1 do
            FX[FXGUID[i]].Collapse = true
        end
    else -- if all is collapsed
        for i = 0, Sel_Track_FX_Count - 1, 1 do
            FX[FXGUID[i]].Collapse = false
            FX.WidthCollapse[FXGUID[i]] = nil
        end
        BlinkFX = FX_Idx
    end
    return BlinkFX
end

function toggle2(a,b)
    if a == b then return nil  else return  b end 
end
---@param str string
---@param DecimalPlaces number
function RoundPrmV(str, DecimalPlaces)
    local A = tostring('%.' .. DecimalPlaces .. 'f')
    --local num = tonumber(str:gsub('[^%d%.]', '')..str:gsub('[%d%.]',''))
    local otherthanNum = str:gsub('[%d%.]', '')
    local num = str:gsub('[^%d%.]', '')
    return string.format(A, tonumber(num) or 0) .. otherthanNum
end

---@param str string
function StrToNum(str)
    return str:gsub('[^%p%d]', '')
end



---TODO empty function
function TableMaxVal()
end

---TODO this is a duplicate, it’s unused and can’t you use #table instead?
---@param T table
---@return integer
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

---@param num number
---@param multipleOf number
---@return number
function roundUp(num, multipleOf)
    return math.floor((num + multipleOf / 2) / multipleOf) * multipleOf;
end

---@param FX_P integer
---@param FxGUID string
---@return unknown
function F_Tp(FX_P, FxGUID) ---TODO this is a duplicate function, and it’s not used anywhere
    return FX.Prm.ToTrkPrm[FxGUID .. FX_P]
end

---@generic T
---@param Table table<string, T>
---@param V T
---@return boolean|nil
---@return T[]|nil
function FindStringInTable(Table, V, Not_Case_Sensitive) ---TODO isn’t this a duplicate of FindExactStringInTable ?  -- this one uses string:find whereas exact uses ==
    local found = nil
    local Tab = {}
    if V then
        for i, val in pairs(Table) do
            if Not_Case_Sensitive then 
                val_low = string.lower(val) 
                V_low  = string.lower(V) 
            end

            if val_low and string.find(val_low, V_low) ~= nil then
                found = true
                table.insert(Tab, val)
            end

        end
        if found == true then return true, Tab, V else return false end
    else
        return nil
    end
end

function Vertical_FX_Name (name)
    local Name = ChangeFX_Name(name)
    local Name = Name:gsub('%S+', { ['Valhalla'] = "", ['FabFilter'] = "" })
    local Name = Name:gsub('-', '|')
    local Name_V = Name:gsub("(.)", "%1\n")
    return   Name_V:gsub("%b()", "") 
end


function PreviewSample_Solo(it, tb , Added)
    if not (it and tb) then  return end 

    r.Main_OnCommand(40769,0) --- Unselect ALL
    if tb and Added then 
        for i, v in ipairs(tb) do 
            r.SetMediaItemInfo_Value(Added[v].it, 'B_UISEL', 1)  --select item 
        end 
    else 
        r.SetMediaItemInfo_Value(it, 'B_UISEL', 1)  --select item 
    end 

    r.Main_OnCommand(41173,0) -- move cursor to start of item

    r.Main_OnCommand(41558, 0 ) -- solo item 
    r.Main_OnCommand(1007,0) --play 
    Solo_Playing_Itm = true 

end 





---@generic T
---@param Table table<string, T>
---@param V T
---@return boolean|nil
---@return T[]|nil
function FindExactStringInTable(Table, V)
    local found = nil
    local Tab = {}
    if V then
        for i, val in pairs(Table) do
            if val == V then
                found = true
                table.insert(Tab, i)
            end
        end
        if found == true then return true, Tab else return false end
    else
        return nil
    end
end

---@param num number|nil|string
---@param numDecimalPlaces number
---@return number|nil
function round(num, numDecimalPlaces)
    num = tonumber(num)
    if num then
        local mult = 10 ^ (numDecimalPlaces or 0)
        return math.floor(num * mult + 0.5) / mult
    end
end

StringToBool = { ['true'] = true, ['false'] = false }

---@generic T
---@param tab table<string, T>
---@param val T
---@return boolean
function has_value(tab, val)
    local found = false
    for index, value in pairs(tab) do
        if value == val then
            found = true
        end
    end
    if found == true then
        return true
    else
        return false
    end
end

function dBFromVal(val) return 20*math.log(val, 10) end
function ValFromdB(dB_val) return 10^(dB_val/20) end

---@generic T
---@param t T[]
---@return T[]|nil
function findDuplicates(t)
    local seen = {}       --keep record of elements we've seen
    local duplicated = {} --keep a record of duplicated elements
    if t then
        for i, v in ipairs(t) do
            local element = t[i]
            if seen[element] then          --check if we've seen the element before
                duplicated[element] = true --if we have then it must be a duplicate! add to a table to keep track of this
            else
                seen[element] = true       -- set the element to seen
            end
        end
        if #duplicated > 1 then
            return duplicated
        else
            return nil
        end
    end
end

--------------ImGUI Related ---------------------
function PinIcon (PinStatus, PinStr, size, lbl, ClrBG, ClrTint )
    if PinStatus == PinStr then 
        if r.ImGui_ImageButton(ctx, '##' .. lbl, Img.Pinned, size, size, nil, nil, nil, nil, ClrBG, ClrTint) then 
            PinStatus = nil 
        end
    else 
        if r.ImGui_ImageButton(ctx, '##' .. lbl, Img.Pin, size, size, nil, nil, nil, nil, ClrBG, ClrTint) then 
            PinStatus = PinStr 
        end
    end
    
        if r.ImGui_IsItemHovered(ctx) then
            TintClr = 0xCE1A28ff
        end
    return PinStatus, TintClr
end

function QuestionHelpHint (Str)
    if r.ImGui_IsItemHovered(ctx) then 
        SL()
        r.ImGui_TextColored(ctx, 0x99999977, '(?)')
        if r.ImGui_IsItemHovered(ctx) then 
            HintToolTip(Str)
        end
    end
end

function GetSelectedMediaItemInfo(which)
    it = r.GetSelectedMediaItem(0, which)
    tk = r.GetMediaItemTake(it, 0)
    src = r.GetMediaItemTake_Source(tk )

    return it, tk, src
end



---@param FillClr number
---@param OutlineClr number
---@param Padding number
---@param L number
---@param T number
---@param R number
---@param B number
---@param h number
---@param w number
---@param H_OutlineSc any
---@param V_OutlineSc any
---@param GetItemRect "GetItemRect"|nil
---@param Foreground? ImGui_DrawList
---@param rounding? number
---@return number|nil L
---@return number|nil T
---@return number|nil R
---@return number|nil B
---@return number|nil w
---@return number|nil h
function HighlightSelectedItem(FillClr, OutlineClr, Padding, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc, GetItemRect,
                               Foreground, rounding, thick)
    if GetItemRect == 'GetItemRect' or L == 'GetItemRect' then
        L, T = r.ImGui_GetItemRectMin(ctx); R, B = r.ImGui_GetItemRectMax(ctx); w, h = r.ImGui_GetItemRectSize(ctx)
        --Get item rect
    end
    local P = Padding or 0 ; local HSC = H_OutlineSc or 4; local VSC = V_OutlineSc or 4
    if Foreground == 'Foreground' then WinDrawList = Glob.FDL else WinDrawList = Foreground end
    if not WinDrawList then WinDrawList = r.ImGui_GetWindowDrawList(ctx) end
    if FillClr then r.ImGui_DrawList_AddRectFilled(WinDrawList, L, T, R, B, FillClr) end

    local h = h or B-T 
    local w = w or R-L

    if OutlineClr and not rounding then
        r.ImGui_DrawList_AddLine(WinDrawList, L - P, T - P, L - P, T + h / VSC - P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, R + P, T - P, R + P, T + h / VSC - P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, L - P, B + P, L - P, B + P - h / VSC, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, R + P, B + P, R + P, B - h / VSC + P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, L - P, T - P, L - P + w / HSC, T - P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, R + P, T - P, R + P - w / HSC, T - P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, L - P, B + P, L - P + w / HSC, B + P, OutlineClr,thick)
        r.ImGui_DrawList_AddLine(WinDrawList, R + P, B + P, R + P - w / HSC, B + P, OutlineClr,thick)
    else
        if FillClr then r.ImGui_DrawList_AddRectFilled(WinDrawList, L, T, R, B, FillClr, rounding) end
        if OutlineClr then r.ImGui_DrawList_AddRect(WinDrawList, L, T, R, B, OutlineClr, rounding) end
    end
    if GetItemRect == 'GetItemRect' then return L, T, R, B, w, h end
end

function Highlight_Itm(ctx, WDL, FillClr, OutlineClr )
    if not WDL then WDL = ImGui.GetWindowDrawList(ctx) end 
    local L, T = r.ImGui_GetItemRectMin(ctx); 
    local R, B = r.ImGui_GetItemRectMax(ctx); 
    
    if FillClr then r.ImGui_DrawList_AddRectFilled(WDL, L, T, R, B, FillClr, rounding) end
    if OutlineClr then r.ImGui_DrawList_AddRect(WDL, L, T, R, B, OutlineClr, rounding) end
end



---@param ctx ImGui_Context
---@param time integer count in
function PopClr(ctx, time)
    r.ImGui_PopStyleColor(ctx, time)
end


function Save_Search_set_Into_File(Search_Set_Name)

    local dir_path = ConcatPath(r.GetResourcePath(), 'Scripts', 'ReaTeam Scripts', 'FX', 'Bryan FX Devices GITHUB', 'Sample Stacker', 'Search Sets')
    local file_path = ConcatPath(dir_path, Search_Set_Name..'.ini')
    r.RecursiveCreateDirectory(dir_path, 0)
    local file = io.open(file_path, 'w')
    if file then 
        local content = file:read("*a")
        file:write('How Many Samples = '..#Added..'\n')
        for i, v in ipairs(Added) do 
            if #v.KeyWord>0 then 
                file:write( 'Sample No.'.. i ..'\n')
                file:write( 'How Many Keywords = '..#v.KeyWord..'\n' )

                for i, v in ipairs(v.KeyWord) do 
                    file:write( 'KeyWord '.. i .. ' = '.. v  ..'\n')
                end 
            end
        end 
    end 
end 




---@param FX_Idx integer
---@param FxGUID string
function SaveDrawings(FX_Idx, FxGUID)
    local dir_path = ConcatPath(r.GetResourcePath(), 'Scripts', 'FX Devices', 'BryanChi_FX_Devices', 'src', 'FX Layouts')
    local FX_Name = ChangeFX_Name(FX_Name)

    local file_path = ConcatPath(dir_path, FX_Name .. '.ini')
    -- Create directory for file if it doesn't exist
    r.RecursiveCreateDirectory(dir_path, 0)
    local file = io.open(file_path, 'r+')

    local D = FX[FxGUID].Draw   

    if file and D then
        local content = file:read("*a")

        if string.find(content, '========== Drawings ==========') then
            file:seek('set', string.find(content, '========== Drawings =========='))
        else
            file:seek('end')
        end
        local function write(Name, Value, ID)
            if ID then
                file:write('D' .. ID .. '. ' .. Name, ' = ', Value or '', '\n')
            else
                file:write(Name, ' = ', Value or '', '\n')
            end
        end
        if D then
            file:write('\n========== Drawings ==========\n')
            write('Default Drawing Edge Rounding', FX[FxGUID].Draw.Df_EdgeRound)
            file:write('\n')
        end
        write('Total Number of Drawings', #D)

        for i, Type in ipairs(D) do
            D[i] = D[i] or {}
            local D = FX[FxGUID].Draw[i] 
            write('Type', D.Type, i)
            write('Left', D.L, i)
            write('Right', D.R, i)
            write('Top', D.T, i)
            write('Bottom', D.B, i)
            write('Color', D.clr, i)
            write('Text', D.Txt, i)
            write('ImagePath', D.FilePath, i)
            write('KeepImgRatio', tostring(D.KeepImgRatio), i)
            file:write('\n')
        end
    end
end

---TODO remove this duplicate of tooltip()
---@param A string text for tooltip
function ttp(A)
    ImGui.BeginTooltip(ctx)
    ImGui.SetTooltip(ctx, A)
    ImGui.EndTooltip(ctx)
end


function Convert_Val2Fader(rea_val)
    if not rea_val then return end
    local rea_val = SetMinMax(rea_val, 0, 4)
    local val
    local gfx_c, coeff = 0.8, 50      -- use coeff to adjust curve
    local real_dB = 20 * math.log(rea_val, 10)
    local lin2 = 10 ^ (real_dB / coeff)
    if lin2 <= 1 then val = lin2 * gfx_c else val = gfx_c + (real_dB / 12) * (1 - gfx_c) end
    if val > 1 then val = 1 end
    return SetMinMax(val, 0.0001, 1)
end

---@param time number
function HideCursor(time)
    UserOS = r.GetOS()
    if UserOS == "OSX32" or UserOS == "OSX64" or UserOS == "macOS-arm64" then
        Invisi_Cursor = r.JS_Mouse_LoadCursorFromFile(r.GetResourcePath() .. '/Cursors/Empty Cursor.cur')
    end
    mx, my = r.GetMousePosition()
    window = r.JS_Window_FromPoint(mx, my)
    release_time = r.time_precise() + (time or 1) -- hide/freeze mouse for 3 secs.

    local function Hide()
        if r.time_precise() < release_time then
            r.JS_Mouse_SetPosition(mx, my)
            r.JS_Mouse_SetCursor(Invisi_Cursor)

            r.defer(Hide)
        else
            r.JS_WindowMessage_Release(window, "WM_SETCURSOR")
        end
    end
    --[[ r.JS_WindowMessage_Intercept(window, "WM_SETCURSOR", false)
        release_time = r.time_precise() + 3 ]]

    Hide()
end
function GetAllInfoNeededEachLoop()
    TimeEachFrame = r.ImGui_GetDeltaTime(ctx)
    if ImGUI_Time == nil then ImGUI_Time = 0 end
    ImGUI_Time             = ImGUI_Time + TimeEachFrame
    _, TrkName             = r.GetTrackName(LT_Track)

    Wheel_V, Wheel_H       = r.ImGui_GetMouseWheel(ctx)
    LT_Track               = r.GetLastTouchedTrack()
    IsAnyMouseDown         = r.ImGui_IsAnyMouseDown(ctx)
    LBtn_MousdDownDuration = r.ImGui_GetMouseDownDuration(ctx, 0)
    LBtnRel                = r.ImGui_IsMouseReleased(ctx, 0)
    RBtnRel                = r.ImGui_IsMouseReleased(ctx, 1)
    IsLBtnClicked          = r.ImGui_IsMouseClicked(ctx, 0)
    LBtnClickCount         = r.ImGui_GetMouseClickedCount(ctx, 0)
    IsLBtnHeld             = r.ImGui_IsMouseDown(ctx, 0)
    IsRBtnHeld             = r.ImGui_IsMouseDown(ctx, 1)
    Mods                   = r.ImGui_GetKeyMods(ctx) -- Alt = 4  shift =2  ctrl = 1  Command=8
    IsRBtnClicked          = r.ImGui_IsMouseClicked(ctx, 1)
    LT_FXGUID              = r.TrackFX_GetFXGUID(LT_Track or r.GetTrack(0, 0),
        LT_FX_Number or 0)
    TrkID                  = r.GetTrackGUID(LT_Track or r.GetTrack(0, 0))
    Sel_Track_FX_Count     = r.TrackFX_GetCount(LT_Track)
    LBtnDrag               = r.ImGui_IsMouseDragging(ctx, 0)
    LBtnDC                 = r.ImGui_IsMouseDoubleClicked(ctx, 0)
end

function HideCursorTillMouseUp(MouseBtn, triggerKey)
    UserOS = r.GetOS()
    if UserOS == "OSX32" or UserOS == "OSX64" or UserOS == "macOS-arm64" then
        Invisi_Cursor = r.JS_Mouse_LoadCursorFromFile(r.GetResourcePath() .. '/Cursors/Empty Cursor.cur')
    end

    if MouseBtn then 
        if r.ImGui_IsMouseDown(ctx, MouseBtn) and not MousePosX_WhenClick then
            MousePosX_WhenClick, MousePosY_WhenClick = r.GetMousePosition()
        end
    elseif triggerKey then 
        if r.ImGui_IsKeyPressed(ctx, triggerKey, false) then 
            MousePosX_WhenClick, MousePosY_WhenClick = r.GetMousePosition()
            
        end
    end

    if MousePosX_WhenClick then
        window = r.JS_Window_FromPoint(MousePosX_WhenClick, MousePosY_WhenClick  )
       
        r.JS_Mouse_SetCursor(Invisi_Cursor)

        local function Hide()
            if MouseBtn and MousePosX_WhenClick then 
                if r.ImGui_IsMouseDown(ctx, MouseBtn) then

                    r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_None())
                    r.defer(Hide)
                else
                    r.JS_WindowMessage_Release(window, "WM_SETCURSOR")
                    if r.ImGui_IsMouseReleased(ctx, MouseBtn) then
                        r.JS_Mouse_SetPosition(MousePosX_WhenClick, MousePosY_WhenClick)
                        MousePosX_WhenClick=nil
                    end
                end
            elseif triggerKey then 

                if r.ImGui_IsKeyDown(ctx, triggerKey) then
                    r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_None())
                    r.defer(Hide)
                else
                    r.JS_WindowMessage_Release(window, "WM_SETCURSOR")
                    if r.ImGui_IsKeyReleased(ctx, triggerKey) then 
                        r.JS_Mouse_SetPosition(MousePosX_WhenClick, MousePosY_WhenClick)
                    end
                end
            end
        end
       -- r.JS_Mouse_SetCursor(Invisi_Cursor)

        Hide()
    end
end


function DiceButton (label, number, w, h, clr, clr2 , fill, outlineClr)
    local WDL = WDL or ImGui.GetWindowDrawList(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local Cx, Cy = x + w/2, y+h/2

    local clr = clr or ImGui.GetStyleColor(ctx,ImGui.Col_Button)
    local clr2 = clr2 or ImGui.GetStyleColor(ctx,ImGui.Col_Text)
    local act = ImGui.InvisibleButton(ctx,label, w, h   )
    ImGui.DrawList_AddRectFilled(WDL, x, y, x+w,y+h , clr, 3 )

    local circle = ImGui.DrawList_AddCircleFilled
    if fill == 'No Fill' then 
        circle = ImGui.DrawList_AddCircle
    end
    if outlineClr then 
        ImGui.DrawList_AddRect(WDL, x, y, x+w,y+h , outlineClr, 3 )
    end

    if number == 1 then 
        circle(WDL, Cx ,Cy,  w/6, clr2)
    elseif number == 2 then 
        circle(WDL, Cx ,Cy - w/4,  w/8, clr2)
        circle(WDL, Cx ,Cy+ w/4,  w/8, clr2)
    elseif number == 3 then 
        circle(WDL, Cx- w/4, Cy- w/4, w/8, clr2)
        circle(WDL, Cx+ w/4, Cy+ w/4, w/8, clr2)
        circle(WDL, Cx, Cy   , w/8, clr2)
    elseif number == 4 then 
        circle(WDL, Cx- w/4, Cy- w/4, w/8, clr2)
        circle(WDL, Cx+ w/4, Cy+ w/4, w/8, clr2)
        circle(WDL, Cx- w/4, Cy+ w/4 , w/8, clr2)
        circle(WDL, Cx+ w/4, Cy- w/4 , w/8, clr2)
    elseif number ==5 then 
        circle(WDL, Cx- w/4, Cy- w/4, w/8, clr2)
        circle(WDL, Cx+ w/4, Cy+ w/4, w/8, clr2)
        circle(WDL, Cx- w/4, Cy+ w/4 , w/8, clr2)
        circle(WDL, Cx+ w/4, Cy- w/4 , w/8, clr2)
        circle(WDL, Cx, Cy   , w/8, clr2)
    elseif number ==6 then 
        circle(WDL, Cx- w/4, Cy- w/4, w/9, clr2)
        circle(WDL, Cx+ w/4, Cy     , w/9, clr2)
        circle(WDL, Cx+ w/4, Cy+ w/4, w/9, clr2)
        circle(WDL, Cx- w/4, Cy+ w/4, w/9, clr2)
        circle(WDL, Cx+ w/4, Cy- w/4, w/9, clr2)
        circle(WDL, Cx- w/4, Cy, w/9, clr2)
    end 
    if ImGui.IsItemActive(ctx) then 
        local act  = Generate_Active_And_Hvr_CLRs(clr)
        ImGui.DrawList_AddRectFilled(WDL, x, y, x+w,y+h , act, 3 )
    end 
    if act then 
        return act
    end 

end


function GetMouseDelta(MouseBtn, triggerKey)
    MouseDelta= MouseDelta or {}
    local M = MouseDelta
    if MouseBtn then 
        if r.ImGui_IsMouseClicked(ctx, MouseBtn)  then
            M.StX, M.StY = r.GetMousePosition()
        end
    end

    if triggerKey then 
        if r.ImGui_IsKeyPressed(ctx, triggerKey, false) then 
            M.StX, M.StY = r.GetMousePosition()
        end
    end

    M.X_now, M.Y_now = r.GetMousePosition()


    if M.StX ~= M.X_now or M.StY ~= M.Y_now then 

        local outX, outY =  M.X_now-M.StX , M.StY - M.Y_now
        local UserOS = r.GetOS()

        if UserOS == "OSX32" or UserOS == "OSX64" or UserOS == "macOS-arm64" then
        else  outY = -outY
        end

        M.StX, M.StY = r.GetMousePosition()
        return outX, outY
    else  return 0, 0
    end


end


---@param Name string
---@param FX_Idx integer
function CreateWindowBtn_Vertical(Name, FX_Idx)
    local rv = r.ImGui_Button(ctx, Name, 25, 220) -- create window name button
    if rv and Mods == 0 then
        openFXwindow(LT_Track, FX_Idx)
    elseif rv and Mods == Shift then
        ToggleBypassFX(LT_Track, FX_Idx)
    elseif rv and Mods == Alt then
        DeleteFX(FX_Idx)
    end
    if r.ImGui_IsItemClicked(ctx, 1) and Mods == 0 then
        FX.Collapse[FXGUID[FX_Idx]] = false
    end
end

function HighlightHvredItem()
    local DL = r.ImGui_GetForegroundDrawList(ctx)
    L, T = r.ImGui_GetItemRectMin(ctx)
    R, B = r.ImGui_GetItemRectMax(ctx)
    if r.ImGui_IsMouseHoveringRect(ctx, L, T, R, B) then
        r.ImGui_DrawList_AddRect(DL, L, T, R, B, 0x99999999)
        r.ImGui_DrawList_AddRectFilled(DL, L, T, R, B, 0x99999933)
        if IsLBtnClicked then
            r.ImGui_DrawList_AddRect(DL, L, T, R, B, 0x999999dd)
            r.ImGui_DrawList_AddRectFilled(DL, L, T, R, B, 0xffffff66)
            return true
        end
    end
end

---@param dur number
---@param rpt integer
---@param var integer | nil
---@param highlightEdge? any -- TODO is this a number?
---@param EdgeNoBlink? "EdgeNoBlink"
---@param L number
---@param T number
---@param R number
---@param B number
---@param h number
---@param w number
---@return nil|integer var
---@return string "Stop"
function BlinkItem(dur, rpt, var, highlightEdge, EdgeNoBlink, L, T, R, B, h, w)
    TimeBegin = TimeBegin or r.time_precise()
    local Now = r.time_precise()
    local EdgeClr = 0x00000000
    if highlightEdge then EdgeClr = highlightEdge end
    local GetItemRect = 'GetItemRect' ---@type string | nil
    if L then GetItemRect = nil end

    if rpt then
        for i = 0, rpt - 1, 1 do
            if Now > TimeBegin + dur * i and Now < TimeBegin + dur * (i + 0.5) then -- second blink
                HighlightSelectedItem(0xffffff77, EdgeClr, 0, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc, GetItemRect,
                    Foreground)
            end
        end
    else
        if Now > TimeBegin and Now < TimeBegin + dur / 2 then
            HighlightSelectedItem(0xffffff77, EdgeClr, 0, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc, GetItemRect,
                Foreground)
        elseif Now > TimeBegin + dur / 2 + dur then
            TimeBegin = r.time_precise()
        end
    end

    if EdgeNoBlink == 'EdgeNoBlink' then
        if Now < TimeBegin + dur * (rpt - 0.95) then
            HighlightSelectedItem(0xffffff00, EdgeClr, 0, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc, GetItemRect,
                Foreground)
        end
    end

    if rpt then
        if Now > TimeBegin + dur * (rpt - 0.95) then
            TimeBegin = nil
            return nil, 'Stop'
        else
            return var
        end
    end
end


function InsertSample(v)
    r.Main_OnCommand(40769,0) --- Unselect ALL
    r.Main_OnCommand(r.NamedCommandLookup('_BR_SAVE_CURSOR_POS_SLOT_16'), 0 )
    local rv = r.InsertMedia(v, 0) --0 is add to current track, 1=add new track, 3=add to selected items as takes
    r.Main_OnCommand(r.NamedCommandLookup('_BR_RESTORE_CURSOR_POS_SLOT_16'), 0)
    return rv 
end 

function Match_Itm_Len_and_Src_Len(src, itm, tk)
    len = r.GetMediaSourceLength(src)
    retval,  section,  start,  len,  fade,  reverse = r.BR_GetMediaSourceProperties(tk)
    rv, rv, len = r.PCM_Source_GetSectionInfo(src)

    r.SetMediaItemInfo_Value(itm, 'D_LENGTH', len)
    r.UpdateArrange()
end
---@param text string
---@param font? ImGui_Font
---@param color? number rgba
---@param WrapPosX? number
function MyText(text, font, color, WrapPosX)
    if WrapPosX then r.ImGui_PushTextWrapPos(ctx, WrapPosX) end

    if font then r.ImGui_PushFont(ctx, font) end
    if color then
        r.ImGui_TextColored(ctx, color, text)
    else
        r.ImGui_Text(ctx, text)
    end

    if font then r.ImGui_PopFont(ctx) end
    if WrapPosX then r.ImGui_PopTextWrapPos(ctx) end
end

function Remove_Dir_path (v)
    if not v then return end 
    local id = string.find(v, "/[^/]*$")
    return v:sub((id or 0 )+1)
end 


function FilterFileType (a, tb )
    local T ={}
    for i, file in pairs(a) do 
        local found 

            local id = (string.find(file, "%.[^%.]*$") or 0 )  + 1
            
            if  FindExactStringInTable(tb, file:sub(id )) then
                found = true 
            end

                
        if found then table.insert(T, file) end 
    end
    return T
end 

---@param ctx ImGui_Context
---@param label string
---@param labeltoShow string
---@param p_value integer
---@param v_min number
---@param v_max number
---@param FX_Idx number
---@param P_Num? number
---@return boolean ActiveAny
---@return boolean ValueChanged
---@return integer p_value
function Add_Pan_Knob(tb, label, labeltoShow, v_min,v_max)
    --r.ImGui_SetNextItemWidth(ctx, 17)
    local radius_outer = 17
    local pos = { r.ImGui_GetCursorScreenPos(ctx) }
    local center = { pos[1] + radius_outer, pos[2] + radius_outer }
    local CircleClr
    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    local item_inner_spacing = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()) }
    local mouse_delta = { ImGui.GetMouseDelta(ctx) }

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    local pan_V =   r.GetMediaItemTakeInfo_Value(tb.tk, "D_PAN")
    local p_value =  (pan_V + 1) / 2  

    r.ImGui_InvisibleButton(ctx, label, radius_outer * 2, radius_outer * 2 + line_height - 10 + item_inner_spacing[2])

    local value_changed = false
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)

    if is_active and mouse_delta[2] ~= 0.0  then
        local step = (v_max - v_min) / 100
        --if Mods == Shift then step = 0.001 end
        local out  = ((pan_V + (-(mouse_delta[2])*step ))) 

        out = SetMinMax(out, -1, 1)
        r.SetMediaItemTakeInfo_Value(tb.tk, "D_PAN", out   )
        r.UpdateArrange()
        
    end
    if is_active and ImGui.IsMouseDoubleClicked(ctx,0) then 
        r.SetMediaItemTakeInfo_Value(tb.tk, "D_PAN", 0   )

    end 
    

    local ClrOverRide , ClrOverRide_Act


    if is_active then
        HideCursorTillMouseUp(0)
        lineClr =  ClrOverRide or r.ImGui_GetColor(ctx, r.ImGui_Col_SliderGrabActive())
        CircleClr = ClrOverRide_Act or Change_Clr_A(  getClr(r.ImGui_Col_SliderGrabActive()), -0.3)
    elseif is_hovered  then
        lineClr = ClrOverRide_Act or Change_Clr_A( getClr(r.ImGui_Col_SliderGrabActive()), -0.3)
    else
        lineClr = ClrOverRide or  r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBgHovered())
    end




    if ActiveAny == true then
        if IsLBtnHeld == false then ActiveAny = false end
    end

    local t = (p_value - v_min) / (v_max - v_min)
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer * 0.40
    



    
    local radius_outer = radius_outer
    
    r.ImGui_DrawList_AddCircle(draw_list, center[1], center[2], radius_outer, CircleClr or lineClr, 16)
    r.ImGui_DrawList_AddLine(draw_list, center[1], center[2], center[1] + angle_cos * (radius_outer - 2),
        center[2] + angle_sin * (radius_outer - 2), lineClr, 2.0)
    r.ImGui_DrawList_AddText(draw_list, pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2],
        reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text()), labeltoShow)


    if is_active or is_hovered --[[ and FX[FxGUID].DeltaP_V ~= 1 ]] then
        local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
        r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1],
            pos[2] - line_height - item_inner_spacing[2] - window_padding[2] - 8)
        ImGui.SetNextWindowSize(ctx, 60, 30)
        r.ImGui_BeginTooltip(ctx)
        local L_or_R 
        if pan_V > 0 then L_or_R = 'R' elseif pan_V < 0 then  L_or_R = 'L' else L_or_R = '' end 


        if Mods == Shift then
            r.ImGui_Text(ctx, ('%.1f'):format(math.abs( (pan_V * 100))).. '% '..L_or_R)
        else
            r.ImGui_Text(ctx, ('%.0f'):format(math.abs( (pan_V * 100))).. '% '..L_or_R)
        end
        r.ImGui_EndTooltip(ctx)
    end
    if is_hovered then HintMessage = 'Alt+Right-Click = Delta-Solo' end
    
    return 

end


function MatchFilesFromKeyWords(words, tb)
    local outTB ={}

    

    for i, v in ipairs(tb) do 
        local not_found 
        for I,V in ipairs(words) do 

            if not  string.lower(v):find(string.lower(V)) then 
                not_found = true 
            end 
        end 

        if not not_found then
            table.insert(outTB, v)
        end


    end 

    return outTB
end 

---@param DL ImGui_DrawList
---@param CenterX number
---@param CenterY number
---@param size number
---@param clr number rgba color
function DrawTriangle(DL, CenterX, CenterY, size, clr)
    local Cx = CenterX
    local Cy = CenterY
    local S = size
    r.ImGui_DrawList_AddTriangleFilled(DL, Cx, Cy - S, Cx - S, Cy, Cx + S, Cy, clr or 0x77777777ff)
end

---@param DL ImGui_DrawList
---@param CenterX number
---@param CenterY number
---@param size number
---@param clr number rgba color
function DrawDownwardTriangle(DL, CenterX, CenterY, size, clr)
    local Cx = CenterX
    local Cy = CenterY
    local S = size
    r.ImGui_DrawList_AddTriangleFilled(DL, Cx - S, Cy, Cx, Cy + S, Cx + S, Cy, clr or 0x77777777ff)
end

---Same Line
---@param xpos? number offset_from_start_xIn
---@param pad? number spacingIn
function SL(xpos, pad)
    r.ImGui_SameLine(ctx, xpos, pad)
end

---@param w number
---@param h number
---@param icon string
---@param BGClr? number
---@param center? string
---@param Identifier? string
---@return boolean|nil
function IconBtn(w, h, icon, BGClr, center, Identifier) -- Y = wrench
    r.ImGui_PushFont(ctx, FontAwesome)
    if r.ImGui_InvisibleButton(ctx, icon .. (Identifier or ''), w, h) then
    end
    local FillClr
    if r.ImGui_IsItemActive(ctx) then
        FillClr = getClr(r.ImGui_Col_ButtonActive())
        IcnClr = getClr(r.ImGui_Col_TextDisabled())
    elseif r.ImGui_IsItemHovered(ctx) then
        FillClr = getClr(r.ImGui_Col_ButtonHovered())
        IcnClr = getClr(r.ImGui_Col_Text())
    else
        FillClr = getClr(r.ImGui_Col_Button())
        IcnClr = getClr(r.ImGui_Col_Text())
    end
    if BGClr then FillClr = BGClr end

    L, T, R, B, W, H = HighlightSelectedItem(FillClr, 0x00000000, 0, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc,
        'GetItemRect', Foreground)
    TxtSzW, TxtSzH = r.ImGui_CalcTextSize(ctx, icon)
    if center == 'center' then
        r.ImGui_DrawList_AddText(WDL, L + W / 2 - TxtSzW / 2, T - H / 2 - 1, IcnClr, icon)
    else
        r.ImGui_DrawList_AddText(WDL, L + 3, T - H / 2, IcnClr, icon)
    end
    r.ImGui_PopFont(ctx)
    if r.ImGui_IsItemActivated(ctx) then return true end
end

---@param f integer
---@return integer
function getClr(f)
    return r.ImGui_GetStyleColor(ctx, f)
end

---@param CLR number
---@param HowMuch number
---@return integer
function Change_Clr_A(CLR, HowMuch)
    local R, G, B, A = r.ImGui_ColorConvertU32ToDouble4(CLR)
    local A = SetMinMax(A + HowMuch, 0, 1)
    return r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
end

---@param Clr number
function Generate_Active_And_Hvr_CLRs(Clr)
    local ActV, HvrV
    local R, G, B, A = r.ImGui_ColorConvertU32ToDouble4(Clr)
    local H, S, V = r.ImGui_ColorConvertRGBtoHSV(R, G, B)
    if V > 0.9 then
        ActV = V - 0.2
        HvrV = V - 0.1
    end
    local R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, SetMinMax(ActV or V + 0.2, 0, 1))
    local ActClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
    local R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, HvrV or V + 0.1)
    local HvrClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
    return ActClr, HvrClr
end

---@param Fx_P integer fx parameter index
---@param FxGUID string
---@param Shape "Circle"|"Rect"
---@param L number p_min_x
---@param T number p_min_y
---@param R? number p_max_x
---@param B? number p_max_y
---@param Rad? number radius
function IfTryingToAddExistingPrm(Fx_P, FxGUID, Shape, L, T, R, B, Rad)
    if Fx_P .. FxGUID == TryingToAddExistingPrm then
        if r.time_precise() > TimeNow and r.time_precise() < TimeNow + 0.1 or r.time_precise() > TimeNow + 0.2 and r.time_precise() < TimeNow + 0.3 then
            if Shape == 'Circle' then
                r.ImGui_DrawList_AddCircleFilled(FX.DL, L, T, Rad, 0x99999950)
            elseif Shape == 'Rect' then
                local L, T = r.ImGui_GetItemRectMin(ctx)
                r.ImGui_DrawList_AddRectFilled(FX.DL, L, T, R, B, 0x99999977, Rounding)
            end
        end
    end
    if Fx_P .. FxGUID == TryingToAddExistingPrm_Cont then
        local L, T = r.ImGui_GetItemRectMin(ctx)
        if Shape == 'Circle' then
            r.ImGui_DrawList_AddCircleFilled(FX.DL, L, T, Rad, 0x99999950)
        elseif Shape == 'Rect' then
            r.ImGui_DrawList_AddRectFilled(FX.DL, L, T, R, B, 0x99999977, Rounding)
        end
    end
end

---@param FxGUID string
---@param FX_Idx integer
---@param LT_Track MediaTrack
---@param PrmCount integer
function RestoreBlacklistSettings(FxGUID, FX_Idx, LT_Track, PrmCount)
    local _, FXsBL = r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: Morph_BL' .. FxGUID, '', false)
    rv, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx)
    local Nm = ChangeFX_Name(FX_Name)
    FX[FxGUID] = FX[FxGUID] or {}
    FX[FxGUID].PrmList = FX[FxGUID].PrmList or {}
    if FXsBL == 'Has Blacklist saved to FX' then -- if there's FX-specific BL settings
        --restore FX specific Blacklist settings
        for i = 0, PrmCount - 4, 1 do
            FX[FxGUID].PrmList[i] = FX[FxGUID].PrmList[i] or {}
            _, FX[FxGUID].PrmList[i].BL = r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: Morph_BL' .. FxGUID .. i,
                '',
                false)
            if FX[FxGUID].PrmList[i].BL == 'Blacklisted' then FX[FxGUID].PrmList[i].BL = true else FX[FxGUID].PrmList[i].BL = nil end
        end
    else                         --if there's no FX-specific BL settings saved
        local _, whether = r.GetProjExtState(0, 'FX Devices - Preset Morph', 'Whether FX has Blacklist' .. (Nm or ''))
        if whether == 'Yes' then -- if there's Project-specific BL settings
            for i = 0, PrmCount - 4, 1 do
                FX[FxGUID].PrmList[i] = FX[FxGUID].PrmList[i] or {}
                ---@type integer, string|number|nil
                local rv, BLprm       = r.GetProjExtState(0, 'FX Devices - Preset Morph', Nm .. ' Blacklist ' .. i)
                if BLprm ~= '' then
                    BLprm = tonumber(BLprm)
                    FX[FxGUID].PrmList[BLprm] = FX[FxGUID].PrmList[BLprm] or {}
                    FX[FxGUID].PrmList[BLprm].BL = true
                else
                end
            end
        else -- Check if need to restore Global Blacklist settings
            file, file_path = CallFile('r', Nm .. '.ini', 'Preset Morphing')
            if file then
                local L = get_lines(file_path)
                for i, V in ipairs(L) do
                    local Num = get_aftr_Equal_Num(V)

                    FX[FxGUID].PrmList[Num] = {}
                    FX[FxGUID].PrmList[Num].BL = true
                end
                file:close()
            end
        end
    end
end

---@param A string text for tooltip
function tooltip(A)
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_SetTooltip(ctx, A)
    r.ImGui_EndTooltip(ctx)
end

---@param A string text for tooltip
function HintToolTip(A)
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_SetTooltip(ctx, A)
    r.ImGui_EndTooltip(ctx)
end

---@param LT_Track MediaTrack
---@param FX_Idx integer
function openFXwindow(LT_Track, FX_Idx)
    FX.Win.FocusState = r.TrackFX_GetOpen(LT_Track, FX_Idx)
    if FX.Win.FocusState == false then
        r.TrackFX_Show(LT_Track, FX_Idx, 3)
    elseif FX.Win.FocusState == true then
        r.TrackFX_Show(LT_Track, FX_Idx, 2)
    end
end

---@param LT_Track MediaTrack
---@param FX_Idx integer
function ToggleBypassFX(LT_Track, FX_Idx)
    FX.Enable = FX.Enable or {}
    FX.Enable[FX_Idx] = r.TrackFX_GetEnabled(LT_Track, FX_Idx)
    if FX.Enable[FX_Idx] == true then
        r.TrackFX_SetEnabled(LT_Track, FX_Idx, false)
    elseif FX.Enable[FX_Idx] == false then
        r.TrackFX_SetEnabled(LT_Track, FX_Idx, true)
    end
end

---@param FX_Idx integer
function DeleteFX(FX_Idx, FxGUID)
    local DelFX_Name
    r.Undo_BeginBlock()
    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. (tablefind(Trk[TrkID].PreFX, FxGUID) or ''),
        '',
        true)
    --r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX '..(tablefind (Trk[TrkID].PostFX, FxGUID) or ''), '', true)

    if tablefind(Trk[TrkID].PreFX, FxGUID) then
        DelFX_Name = 'FX in Pre-FX Chain'
        table.remove(Trk[TrkID].PreFX, tablefind(Trk[TrkID].PreFX, FxGUID))
    end

    if tablefind(Trk[TrkID].PostFX, FxGUID) then
        table.remove(Trk[TrkID].PostFX, tablefind(Trk[TrkID].PostFX, FxGUID))
        for i = 1, #Trk[TrkID].PostFX + 1, 1 do
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX ' .. i, Trk[TrkID].PostFX[i] or '', true)
        end
    end

    if FX[FxGUID].InWhichBand then -- if FX is in band split
        for i = 0, Sel_Track_FX_Count - 1, 1 do
            if FX[FXGUID[i]].FXsInBS then
                if tablefind(FX[FXGUID[i]].FXsInBS, FxGUID) then
                    table.remove(FX[FXGUID[i]].FXsInBS, tablefind(FX[FXGUID[i]].FXsInBS, FxGUID))
                end
            end
        end
    end

    DeleteAllParamOfFX(FxGUID, TrkID)



    if FX_Name:find('Pro Q 3') ~= nil and not FXinPost and not FXinPre then
        r.TrackFX_Delete(LT_Track, FX_Idx)
        r.TrackFX_Delete(LT_Track, FX_Idx - 1)
        DelFX_Name = 'Pro Q 3'
    elseif FX_Name:find('Pro C 2') ~= nil and not FXinPost and not FXinPre then
        DelFX_Name = 'Pro C 2'
        r.TrackFX_Delete(LT_Track, FX_Idx + 1)
        r.TrackFX_Delete(LT_Track, FX_Idx)
        r.TrackFX_Delete(LT_Track, FX_Idx - 1)
    else
        r.TrackFX_Delete(LT_Track, FX_Idx)
    end



    r.Undo_EndBlock('Delete ' .. (DelFX_Name or 'FX'), 0)
end

---@param FxGUID string
---@param Fx_P integer parameter index
---@param FX_Idx integer
function DeletePrm(FxGUID, Fx_P, FX_Idx)
    --LE.Sel_Items[1] = nil
    local FP = FX[FxGUID][Fx_P]
    for i, v in ipairs(FX[FxGUID]) do
        if v.ConditionPrm then
            v.ConditionPrm = nil
        end
    end


    if FP.WhichMODs then
        Trk[TrkID].ModPrmInst = Trk[TrkID].ModPrmInst - 1
        FX[FxGUID][Fx_P].WhichCC = nil
        r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX' .. FxGUID .. 'WhichCC' .. FP.Num, '', true)

        FX[FxGUID][Fx_P].WhichMODs = nil
        r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX' .. FxGUID .. 'Prm' .. Fx_P .. 'Linked to which Mods', '',
            true)
    end

    for Mc = 1, 8, 1 do
        if FP.ModAMT then
            if FP.ModAMT[Mc] then
                local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..FP.Num..".plink.active", 0)   -- 1 active, 0 inactive
                FP.ModAMT[Mc] = nil
            end
        end
    end

    table.remove(FX[FxGUID], Fx_P)
    if Trk.Prm.Inst[TrkID] then
        Trk.Prm.Inst[TrkID] = Trk.Prm.Inst[TrkID] - 1
        r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: Trk Prm Count', Trk.Prm.Inst[TrkID], true)
    end


    for i, v in ipairs(FX[FxGUID]) do
        r.SetProjExtState(0, 'FX Devices', 'FX' .. i .. 'Name' .. FxGUID, FX[FxGUID][i].Name)
        r.SetProjExtState(0, 'FX Devices', 'FX' .. i .. 'Num' .. FxGUID, FX[FxGUID][i].Num)
    end
    r.SetProjExtState(0, 'FX Devices', 'Prm Count' .. FxGUID, #FX[FxGUID])
    -- Delete Proj Ext state data!!!!!!!!!!
end

function SyncTrkPrmVtoActualValue()
    for FX_Idx = 0, Sel_Track_FX_Count, 1 do                 ---for every selected FX in cur track
        local FxGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx) ---get FX’s GUID
        if FxGUID then
            FX[FxGUID] = FX[FxGUID] or {}                    ---create new params table for FX if it doesn’t exist
            for Fx_P = 1, #FX[FxGUID] or 0, 1 do             ---for each param
                if TrkID then
                    if not FX[FxGUID][Fx_P].WhichMODs then
                        FX[FxGUID][Fx_P].V = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, FX[FxGUID][Fx_P].Num or 0) ---get param value
                    end
                end
            end
        end
    end
end

-------------General Functions ------------------------------



---@param directory string path to directory
---@return table
function scandir(directory)
    local Files = {}
    for i = 0, 999, 1 do
        local F = r.EnumerateFiles(directory, i)
        
        if F and F ~= '.DS_Store' then table.insert(Files, F) end

        if not F then return Files end
    end

    --return F ---TODO should this be Files instead of F ?
end

---@param ShowAlreadyAddedPrm boolean
---@return boolean|unknown
function IsPrmAlreadyAdded(ShowAlreadyAddedPrm)
    GetLTParam()
    local FX_Count = r.TrackFX_GetCount(LT_Track); local RptPrmFound
    local F = FX[LT_FXGUID] or {}

    if F then
        for i, v in ipairs(F) do
            if FX[LT_FXGUID][i].Num == LT_ParamNum then
                RptPrmFound = true

                if ShowAlreadyAddedPrm then
                    TryingToAddExistingPrm = i .. LT_FXGUID
                    TimeNow = r.time_precise()
                end
            end
        end
        --[[ if not RptPrmFound and LT_FXGUID then
                StoreNewParam(LT_FXGUID, LT_ParamName, LT_ParamNum, LT_FXNum, true )
            end ]]
    end
    return RptPrmFound
end

---@param str string | nil
---@return nil|string
function RemoveEmptyStr(str)
    if str == '' then return nil else return str end
end

---@param T table
---@return integer
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end
---@param Rpt integer
function AddSpacing(Rpt)
    for i = 1, Rpt, 1 do
        r.ImGui_Spacing(ctx)
    end
end

function AddWindowBtn (FxGUID, FX_Idx, width, CantCollapse, CantAddPrm, isContainer)
    
    if FX[FxGUID] then 
        if FX[FxGUID].TitleClr then
            WinbtnClrPop = 3
            if not FX[FxGUID].TitleClrHvr then
                FX[FxGUID].TitleClrAct, FX[FxGUID].TitleClrHvr = Generate_Active_And_Hvr_CLRs(
                    FX[FxGUID].TitleClr)
            end
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(),
                FX[FxGUID].TitleClrHvr or 0x22222233)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),
                FX[FxGUID].TitleClrAct or 0x22222233)
        else
            WinbtnClrPop = 1
        end
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), FX[FxGUID].TitleClr or 0x22222233)
        local WindowBtn



        if not FX[FxGUID].Collapse  and not FX[FxGUID].V_Win_Btn_Height or isContainer then
            if not FX[FxGUID].NoWindowBtn then 
                local Name = (FX[FxGUID].CustomTitle  or ChangeFX_Name(select(2,r.TrackFX_GetFXName(LT_Track,FX_Idx))).. '## ')
                if DebugMode then Name = FxGUID end
                WindowBtn = r.ImGui_Button(ctx, Name .. '## '..FxGUID, width or FX[FxGUID].TitleWidth or Default_FX_Width - 30, 20) -- create window name button


                if r.ImGui_IsItemHovered(ctx) and FindStringInTable(SpecialLayoutFXs, FX_Name) == false then
                    FX[FxGUID].TtlHvr = true
                    if not CantAddPrm then 
                        TtlR, TtlB = r.ImGui_GetItemRectMax(ctx)
                        if r.ImGui_IsMouseHoveringRect(ctx, TtlR - 20, TtlB - 20, TtlR, TtlB) then
                            r.ImGui_DrawList_AddRectFilled(WDL, TtlR, TtlB, TtlR - 20, TtlB - 20,
                                getClr(r.ImGui_Col_ButtonHovered()))
                            r.ImGui_DrawList_AddRect(WDL, TtlR, TtlB, TtlR - 20, TtlB - 19,
                                getClr(r.ImGui_Col_Text()))
                            r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 20, TtlR - 15,
                                TtlB - 20, getClr(r.ImGui_Col_Text()), '+')
                            if IsLBtnClicked then
                                r.ImGui_OpenPopup(ctx, 'Add Parameter' .. FxGUID)
                                r.ImGui_SetNextWindowPos(ctx, TtlR, TtlB)
                                AddPrmPopupOpen = FxGUID
                            end
                        end
                    end
                else
                    FX[FxGUID].TtlHvr = nil
                end
            end
        elseif FX[FxGUID].V_Win_Btn_Height and not FX[FxGUID].Collapse then 
            local Name = (FX[FxGUID].CustomTitle or FX.Win_Name_S[FX_Idx] or ChangeFX_Name(select(2,r.TrackFX_GetFXName(LT_Track,FX_Idx))).. '## ')

            local Name_V_NoManuFacturer = Vertical_FX_Name (Name)
           -- r.ImGui_PushStyleVar(ctx, BtnTxtAlign, 0.5, 0.2) --StyleVar#3
            --r.ImGui_SameLine(ctx, nil, 0)

             WindowBtn = r.ImGui_Button(ctx, Name_V_NoManuFacturer..'##'..FxGUID, 25, FX[FxGUID].V_Win_Btn_Height)

           -- r.ImGui_PopStyleVar(ctx)             --StyleVar#3 POP
        else  -- if collapsed
            FX.WidthCollapse[FxGUID] = 27
            local Name = (FX[FxGUID].CustomTitle or FX.Win_Name_S[FX_Idx] or ChangeFX_Name(select(2,r.TrackFX_GetFXName(LT_Track,FX_Idx))).. '## ')
            
            local Name_V_NoManuFacturer = Vertical_FX_Name (Name)
            r.ImGui_PushStyleVar(ctx, BtnTxtAlign, 0.5, 0.2) --StyleVar#3
            --r.ImGui_SameLine(ctx, nil, 0)
            
            WindowBtn = r.ImGui_Button(ctx, Name_V_NoManuFacturer..'##'..FxGUID, 25, 220)
            r.ImGui_PopStyleVar(ctx)             --StyleVar#3 POP
        end
        r.ImGui_PopStyleColor(ctx, WinbtnClrPop) -- win btn clr

        local BgClr 
        FX.Enable[FX_Idx] = r.TrackFX_GetEnabled(LT_Track, FX_Idx)
        
        if not FX.Enable[FX_Idx] then
            --r.ImGui_DrawList_AddRectFilled(WDL, L, T - 20, R, B +20, 0x00000088)
            BgClr = 0x00000088
        end
        HighlightSelectedItem(BgClr, 0xffffff11, -1, L, T, R, B, h, w, 1, 1, 'GetItemRect', WDL, FX[FxGUID].Round --[[rounding]])


       -- r.ImGui_SetNextWindowSizeConstraints(ctx, AddPrmWin_W or 50, 50, 9999, 500)
        local R_ClickOnWindowBtn = r.ImGui_IsItemClicked(ctx, 1)
        local L_ClickOnWindowBtn = r.ImGui_IsItemClicked(ctx)

        if not CantCollapse then 
            if R_ClickOnWindowBtn and Mods == Ctrl then
                r.ImGui_OpenPopup(ctx, 'Fx Module Menu')
            elseif R_ClickOnWindowBtn and Mods == 0 then
                FX[FxGUID].Collapse = toggle(FX[FxGUID].Collapse)
                if not FX[FxGUID].Collapse then FX.WidthCollapse[FxGUID] = nil end
            elseif R_ClickOnWindowBtn and Mods == Alt then
                -- check if all are collapsed
                BlinkFX = ToggleCollapseAll(FX_Idx)
            end
        end


        if WindowBtn and Mods == 0 then

            openFXwindow(LT_Track, FX_Idx)
        elseif WindowBtn and Mods == Shift then
            ToggleBypassFX(LT_Track, FX_Idx)
        elseif WindowBtn and Mods == Alt then
            DeleteFX(FX_Idx,FxGUID)
        end

        if r.ImGui_IsItemHovered(ctx) then
            HintMessage =
            'Mouse: L=Open FX Window | Shift+L = Toggle Bypass | Alt+L = Delete | R = Collapse | Alt+R = Collapse All'
        end


        ----==  Drag and drop----
        if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptNoDrawDefaultRect()) then
            DragFX_ID = FX_Idx
            DragFxGuid = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
            r.ImGui_SetDragDropPayload(ctx, 'FX_Drag', FX_Idx)
            r.ImGui_EndDragDropSource(ctx)

            DragDroppingFX = true
            if IsAnyMouseDown == false then DragDroppingFX = false end
            HighlightSelectedItem(0xffffff22, 0xffffffff, 0, L, T, R, B, h, w, H_OutlineSc, V_OutlineSc, 'GetItemRect', WDL)
            Post_DragFX_ID = tablefind(Trk[TrkID].PostFX, FxGUID_DragFX)
        end

        if IsAnyMouseDown == false and DragDroppingFX == true then
            DragDroppingFX = false
        end

        ----Drag and drop END----

        

        if R_ClickOnWindowBtn then return 2 
        elseif L_ClickOnWindowBtn then return 1 
        end 
        
    end

end

function DndAddFX_SRC(fx)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
      r.ImGui_SetDragDropPayload(ctx, 'DND ADD FX', fx)
      r.ImGui_Text(ctx, fx)
      r.ImGui_EndDragDropSource(ctx)
    end
end

function DndAddFXfromBrowser_TARGET(Dest, ClrLbl, SpaceIsBeforeRackMixer, SpcIDinPost)

    --if not DND_ADD_FX then return  end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ADD FX')
        
        
        if dropped then
            local FX_Idx = Dest
            if SpaceIsBeforeRackMixer == 'End of PreFX' then FX_Idx = FX_Idx + 1 end
            
            r.TrackFX_AddByName(LT_Track, payload, false, -1000 - FX_Idx, false)
            local FxID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
            local _, nm = r.TrackFX_GetFXName(LT_Track, FX_Idx)

                --if in layer
            if FX.InLyr[FXGUID_To_Check_If_InLayer] == FXGUID_RackMixer and SpaceIsBeforeRackMixer == false or AddLastSPCinRack == true then
                DropFXtoLayerNoMove(FXGUID_RackMixer, LyrID, FX_Idx)
            end
            Dvdr.Clr[ClrLbl or ''], Dvdr.Width[TblIdxForSpace or ''] = nil, 0
            if SpcIsInPre then
                if SpaceIsBeforeRackMixer == 'End of PreFX' then
                    table.insert(Trk[TrkID].PreFX, FxID)
                else
                table.insert(Trk[TrkID].PreFX, FX_Idx + 1, FxID)
                end
                for i, v in pairs(Trk[TrkID].PreFX) do r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. i, v,
                    true) end
            elseif SpcInPost then
                if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) == -1 then offset = -1 else offset = 0 end
                table.insert(Trk[TrkID].PostFX, SpcIDinPost + offset + 1, FxID)
                -- InsertToPost_Src = FX_Idx + offset+2
                for i = 1, #Trk[TrkID].PostFX + 1, 1 do
                r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX ' .. i, Trk[TrkID].PostFX[i] or '', true)
                end
            elseif SpaceIsBeforeRackMixer == 'SpcInBS' then
                DropFXintoBS(FxID, FxGUID_Container, FX[FxGUID_Container].Sel_Band, FX_Idx, Dest + 1)
            end
            FX_Idx_OpenedPopup = nil

        end

    end
    r.ImGui_PopStyleColor(ctx)
end

function AddFX_Menu(FX_Idx)
    local function DrawFxChains(tbl, path)
        local extension = ".RfxChain"
        path = path or ""
        for i = 1, #tbl do
            if tbl[i].dir then
                if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                    DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                    r.ImGui_EndMenu(ctx)
                end
            end
            if type(tbl[i]) ~= "table" then
                if r.ImGui_Selectable(ctx, tbl[i]) then
                    if TRACK then
                        r.TrackFX_AddByName(TRACK, table.concat({ path, os_separator, tbl[i], extension }), false,
                            -1000 - FX_Idx)
                    end
                end
                DndAddFX_SRC(table.concat({ path, os_separator, tbl[i], extension }))
            end
        end
    end
    local function LoadTemplate(template, replace)
        local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
        if replace then
            local chunk = GetFileContext(track_template_path)
            r.SetTrackStateChunk( TRACK, chunk, true )
        else
            r.Main_openProject( track_template_path )
        end
    end
    local function DrawTrackTemplates(tbl, path)
        local extension = ".RTrackTemplate"
        path = path or ""
        for i = 1, #tbl do
            if tbl[i].dir then
                if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                    local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                    DrawTrackTemplates(tbl[i], cur_path)
                    r.ImGui_EndMenu(ctx)
                end
            end
            if type(tbl[i]) ~= "table" then
                if r.ImGui_Selectable(ctx, tbl[i]) then
                    local template_str = table.concat({ path, os_separator, tbl[i], extension })
                    LoadTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
                end
            end
        end
    end

    if r.ImGui_BeginPopup(ctx, 'Btwn FX Windows' .. FX_Idx) then
        local AddedFX
        FX_Idx_OpenedPopup = FX_Idx .. (tostring(SpaceIsBeforeRackMixer) or '')

        if FilterBox(FX_Idx, LyrID, SpaceIsBeforeRackMixer, FxGUID_Container, SpcIsInPre, SpcInPost,SpcIDinPost) then
            AddedFX=true 
            r.ImGui_CloseCurrentPopup(ctx)
        end -- Add FX Window
        r.ImGui_SeparatorText(ctx, "PLUGINS")
        for i = 1, #CAT do
            if r.ImGui_BeginMenu(ctx, CAT[i].name) then
                if CAT[i].name == "FX CHAINS" then
                    DrawFxChains(CAT[i].list)
                elseif CAT[i].name == "TRACK TEMPLATES" then -- THIS IS MISSING
                    DrawTrackTemplates(CAT[i].list)                        
                else
                    for j = 1, #CAT[i].list do
                        if r.ImGui_BeginMenu(ctx, CAT[i].list[j].name ) then
                            for p = 1, #CAT[i].list[j].fx do
                                if CAT[i].list[j].fx[p] then
                                    if r.ImGui_Selectable(ctx, CAT[i].list[j].fx[p]) then
                                        if TRACK then
                                            AddedFX = true 
                                            r.TrackFX_AddByName(TRACK, CAT[i].list[j].fx[p], false,-1000 - FX_Idx)
                                            LAST_USED_FX = CAT[i].list[j].fx[p]
                                        end
                                    end
                                end
                            end
                            r.ImGui_EndMenu(ctx)
                        end
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
        end
        if r.ImGui_BeginMenu(ctx, "FXD INSTRUMENTS & EFFECTS") then
            if r.ImGui_Selectable(ctx, "ReaDrum Machine") then
                local chain_src = "../Scripts/FX Devices/BryanChi_FX_Devices/src/FXChains/ReaDrum Machine.RfxChain"
                local found = false
                count = r.TrackFX_GetCount(TRACK) -- 1 based
                for i = 0, count - 1 do
                  local rv, rename = r.TrackFX_GetNamedConfigParm(TRACK, i, 'renamed_name') -- 0 based
                  if rename == 'ReaDrum Machine' then
                    found = true
                    break
                  end
                end
                if not found then
                r.Undo_BeginBlock()
                r.PreventUIRefresh(1)
                r.TrackFX_AddByName(TRACK, chain_src, false, -1000 - FX_Idx)
                AddedFX=true
                r.PreventUIRefresh(-1)
                EndUndoBlock("ADD DRUM MACHINE")
                end
            end
            DndAddFX_SRC("../Scripts/FX Devices/BryanChi_FX_Devices/src/FXChains/ReaDrum Machine.RfxChain")
            r.ImGui_EndMenu(ctx)
        end
        TRACK = r.GetSelectedTrack(0, 0)
        if r.ImGui_Selectable(ctx, "CONTAINER") then
            r.TrackFX_AddByName(TRACK, "Container", false, -1000 - FX_Idx)
            AddedFX=true
            LAST_USED_FX = "Container"
        end
        DndAddFX_SRC("Container")
        if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then
            r.TrackFX_AddByName(TRACK, "Video processor", false, -1000 - FX_Idx)
            AddedFX=true
            LAST_USED_FX = "Video processor"
        end
        DndAddFX_SRC("Video processor")
        if LAST_USED_FX then
            if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
                r.TrackFX_AddByName(TRACK, LAST_USED_FX, false, -1000 - FX_Idx)
                AddedFX=true
            end
        end
        DndAddFX_SRC(LAST_USED_FX)
        r.ImGui_SeparatorText(ctx, "UTILS")
        if r.ImGui_Selectable(ctx, 'Add FX Layering', false) then
            local FX_Idx = FX_Idx
            --[[ if FX_Name:find('Pro%-C 2') then FX_Idx = FX_Idx-1 end ]]
            local val = r.SNM_GetIntConfigVar("fxfloat_focus", 0)
            if val & 4 ~= 0 then
                r.SNM_SetIntConfigVar("fxfloat_focus", val & (~4))
            end

            if r.GetMediaTrackInfo_Value(LT_Track, 'I_NCHAN') < 16 then
                r.SetMediaTrackInfo_Value(LT_Track, 'I_NCHAN', 16)
            end
            FXRack = r.TrackFX_AddByName(LT_Track, 'FXD (Mix)RackMixer', 0, -1000 - FX_Idx)
            local RackFXGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)

            ChanSplitr = r.TrackFX_AddByName(LT_Track, 'FXD Split to 32 Channels', 0,
                -1000 - FX_Idx)
            local SplitrGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
            Lyr.SplitrAttachTo[SplitrGUID] = RackFXGUID
            r.SetProjExtState(0, 'FX Devices', 'SplitrAttachTo' .. SplitrGUID, RackFXGUID)
            _, ChanSplitFXName = r.TrackFX_GetFXName(LT_Track, FX_Idx - 1)

            FX[RackFXGUID] = FX[RackFXGUID] or {}
            FX[RackFXGUID].LyrID = FX[RackFXGUID].LyrID or {}
            table.insert(FX[RackFXGUID].LyrID, 1)
            table.insert(FX[RackFXGUID].LyrID, 2)

            r.SetProjExtState(0, 'FX Devices', 'FX' .. RackFXGUID .. 'Layer ID 1', 1)
            r.SetProjExtState(0, 'FX Devices', 'FX' .. RackFXGUID .. 'Layer ID 2', 2)
            FX[RackFXGUID].ActiveLyrCount = 2

            FX_Layr_Inst = 0
            for F = 0, Sel_Track_FX_Count, 1 do
                local FXGUID = r.TrackFX_GetFXGUID(LT_Track, F)
                local _, FX_Name = r.TrackFX_GetFXName(LT_Track, F)
                if string.find(FX_Name, 'FXD Split to 32 Channels') ~= nil then
                    FX_Layr_Inst                       = FX_Layr_Inst + 1
                    Lyr.SpltrID[FX_Layr_Inst .. TrkID] = r.TrackFX_GetFXGUID(LT_Track,
                        FX_Idx - 1)
                end
            end

            Spltr[SplitrGUID] = Spltr[SplitrGUID] or {}
            Spltr[SplitrGUID].New = true


            if FX_Layr_Inst == 1 then
                --sets input channels to 1 and 2
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 0, 0, 1, 0)
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 0, 1, 2, 0)
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 0, 2, 1, 0)
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 0, 3, 2, 0)
                for i = 2, 16, 1 do
                    r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 0, i, 0, 0)
                end
                --sets Output to all channels
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 1, 0, 21845, 0)
                r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 1, 1, 43690, 0)
                for i = 2, 16, 1 do
                    r.TrackFX_SetPinMappings(LT_Track, FX_Idx - 1, 1, i, 0, 0)
                end
            elseif FX_Layr_Inst > 1 then

            end




            FX_Idx_OpenedPopup = nil
            r.ImGui_CloseCurrentPopup(ctx)
            if val & 4 ~= 0 then
                r.SNM_SetIntConfigVar("fxfloat_focus", val|4) -- re-enable Auto-float
            end
        elseif r.ImGui_Selectable(ctx, 'Add Band Split', false) then
            r.gmem_attach('FXD_BandSplit')
            table.insert(AddFX.Name, 'FXD Saike BandSplitter')
            table.insert(AddFX.Pos, FX_Idx)
            table.insert(AddFX.Name, 'FXD Band Joiner')
            table.insert(AddFX.Pos, FX_Idx + 1)
            if r.GetMediaTrackInfo_Value(LT_Track, 'I_NCHAN') < 12 then -- Set track channels to 10 if it's lower than 10
                r.SetMediaTrackInfo_Value(LT_Track, 'I_NCHAN', 12)
            end

            FX_Idx_OpenedPopup = nil
            --r.TrackFX_AddByName(LT_Track, 'FXD Bandjoiner', 0, -1000-FX_Idx)
        end
        --DndAddFX_SRC("FXD Saike BandSplitter")

        Dvdr.Spc_Hover[TblIdxForSpace] = Dvdr_Hvr_W
        --Dvdr.Clr[ClrLbl] = 0x999999ff

        if IsLBtnClicked then FX_Idx_OpenedPopup = nil end

        if AddedFX then  RetrieveFXsSavedLayout(Sel_Track_FX_Count) end 



        if CloseAddFX_Popup then
            r.ImGui_CloseCurrentPopup(ctx)
            CloseAddFX_Popup = nil
        end
        r.ImGui_EndPopup(ctx)
    else
        Dvdr.Clr[ClrLbl or ''] = 0x131313ff
    end

end

--[[ function HideCursorTillMouseUp(MouseBtn, ifneedctx)
    if ifneedctx then ctx = ifneedctx end
    UserOS = r.GetOS()
    if UserOS == "OSX32" or UserOS == "OSX64" or UserOS == "macOS-arm64" then
        Invisi_Cursor = reaper.JS_Mouse_LoadCursorFromFile(r.GetResourcePath() .. '/Cursors/Empty Cursor.cur')
    end

    if r.ImGui_IsMouseClicked(ctx, MouseBtn) then
        MousePosX_WhenClick, MousePosY_WhenClick = r.GetMousePosition()
    end

    if MousePosX_WhenClick then
        window = r.JS_Window_FromPoint(MousePosX_WhenClick, MousePosY_WhenClick)

        local function Hide()
            if r.ImGui_IsMouseDown(ctx, MouseBtn) then
                r.JS_Mouse_SetCursor(Invisi_Cursor)
                r.defer(Hide)
            else
                reaper.JS_WindowMessage_Release(window, "WM_SETCURSOR")
                if r.ImGui_IsMouseReleased(ctx, MouseBtn) then
                    r.JS_Mouse_SetPosition(MousePosX_WhenClick, MousePosY_WhenClick)
                end
            end
        end
        Hide()
    end
end ]]


function createFXWindow(FX_Idx, Cur_X_Ofs)
    local FxGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
    local HoverWindow

    if --[[ FXGUID[FX_Idx] ~= FXGUID[FX_Idx - 1] and ]] FxGUID then
        FX[FxGUID] = FX[FxGUID] or {}
        r.ImGui_BeginGroup(ctx)

        FX.Enable[FX_Idx] = r.TrackFX_GetEnabled(LT_Track, FX_Idx)
        local _, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx)
        --local FxGUID = FXGUID[FX_Idx]
        local FxNameS = FX.Win_Name_S[FX_Idx]
        local Hide
        FX.DL = r.ImGui_GetWindowDrawList(ctx)

        if FX_Name == 'Container' --[[ and FX_Idx < 0x2000000 ]]  then 
            ContainerX, ContainerY =r.ImGui_GetCursorScreenPos(ctx)
        end

        FX_Name = string.sub(FX_Name, 1, (string.find(FX_Name, '%(') or 30) - 1)
        FX_Name = string.gsub(FX_Name, '-', ' ')
        WDL = FX.DL
        FX[FxGUID] = FX[FxGUID] or {}
        if FX[FxGUID].MorphA and not FX[FxGUID].MorphHide then
            local OrigCurX, OrigCurY = r.ImGui_GetCursorPos(ctx)

            DefClr_A_Act = Morph_A or CustomColorsDefault.Morph_A
            DefClr_A = Change_Clr_A(DefClr_A_Act, -0.2)
            DefClr_A_Hvr = Change_Clr_A(DefClr_A_Act, -0.1)
            DefClr_B_Act = Morph_B or CustomColorsDefault.Morph_B
            DefClr_B = Change_Clr_A(DefClr_B_Act, -0.2)
            DefClr_B_Hvr = Change_Clr_A(DefClr_B_Act, -0.1)


            function StoreAllPrmVal(AB, DontStoreCurrentVal, LinkCC)
                local PrmCount = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                for i = 0, PrmCount - 4, 1 do
                    local _, name = r.TrackFX_GetParamName(LT_Track, FX_Idx, i)
                    local Prm_Val, minval, maxval = r.TrackFX_GetParamNormalized(LT_Track,
                        FX_Idx, i)
                    if AB == 'A' then
                        if DontStoreCurrentVal ~= 'Dont' then FX[FxGUID].MorphA[i] = Prm_Val end
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FX Morph A' .. i .. FxGUID,
                            FX[FxGUID].MorphA[i], true)
                        if LinkCC then
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.active", 1)   -- 1 active, 0 inactive
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.scale", FX[FxGUID].MorphB[i])   -- Scale
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.effect", -100) -- -100 enables midi_msg*
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.param", -1)   -- -1 not parameter link
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg", 160)   -- 160 is Aftertouch
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg2", LinkCC) -- CC value
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".mod.baseline", Prm_Val) -- Baseline                                                
                        end
                    else
                        if DontStoreCurrentVal ~= 'Dont' then FX[FxGUID].MorphB[i] = Prm_Val end
                        if FX[FxGUID].MorphB[i] then
                            r.GetSetMediaTrackInfo_String(LT_Track,
                                'P_EXT: FX Morph B' .. i ..
                                FxGUID, FX[FxGUID].MorphB[i], true)
                            if LinkCC then
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.active", 1)   -- 1 active, 0 inactive
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.scale", Prm_Val - FX[FxGUID].MorphA[i])   -- Scale
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.effect", -100) -- -100 enables midi_msg*
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.param", -1)   -- -1 not parameter link
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg", 160)   -- 160 is Aftertouch
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg2", LinkCC) -- CC value
                                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".mod.baseline", FX[FxGUID].MorphA[i]) -- Baseline                                                    
                            end
                        end
                    end
                end
                if DontStoreCurrentVal ~= 'Dont' then
                    local rv, presetname = r.TrackFX_GetPreset(LT_Track, FX_Idx)
                    if rv and AB == 'A' then
                        FX[FxGUID].MorphA_Name = presetname
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FX Morph A' .. FxGUID .. 'Preset Name', presetname, true)
                    elseif rv and AB == 'B' then
                        FX[FxGUID].MorphB_Name = presetname
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FX Morph B' .. FxGUID .. 'Preset Name', presetname, true)
                    end
                end
            end

            r.ImGui_SetNextItemWidth(ctx, 20)
            local x, y = r.ImGui_GetCursorPos(ctx)
            x = x - 2
            local SCx, SCy = r.ImGui_GetCursorScreenPos(ctx)
            SCx = SCx - 2
            r.ImGui_SetCursorPosX(ctx, x)

            --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),DefClr_A) r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), DefClr_A_Hvr) r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), DefClr_A_Act)

            if r.ImGui_Button(ctx, 'A##' .. FxGUID, 20, 20) then
                StoreAllPrmVal('A', nil, FX[FxGUID].Morph_ID)
            end
            --r.ImGui_PopStyleColor(ctx,3)


            if r.ImGui_IsItemHovered(ctx) and FX[FxGUID].MorphA_Name then
                if FX[FxGUID].MorphA_Name ~= '' then
                    HintToolTip(FX[FxGUID].MorphA_Name)
                end
            end

            local H = 180
            r.ImGui_SetCursorPos(ctx, x, y + 20)

            r.ImGui_InvisibleButton(ctx, '##Morph' .. FxGUID, 20, H)

            local BgClrA, isActive, V_Pos, DrgSpdMod, SldrActClr, BtnB_TxtClr, ifHvr
            local M = PresetMorph


            if r.ImGui_IsItemActive(ctx) then
                BgClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_FrameBgActive())
                isActive = true
                BgClrA = DefClr_A_Act
                BgClrB =
                    DefClr_B_Act -- shift 0x00RRGGBB to 0xRRGGBB00 then add 0xFF for 100% opacity
            elseif r.ImGui_IsItemHovered(ctx) then
                ifHvr = true
                BgClrA = DefClr_A_Hvr
                BgClrB = DefClr_B_Hvr
            else
                BgClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_FrameBg())
                BgClrA = DefClr_A
                BgClrB = DefClr_B
            end
            if --[[Ctrl + R click]] r.ImGui_IsItemClicked(ctx, 1) and Mods == Ctrl then
                r.ImGui_OpenPopup(ctx, 'Morphing menu' .. FX_Idx)
            end

            local L, T = r.ImGui_GetItemRectMin(ctx)
            local R, B = r.ImGui_GetItemRectMax(ctx)
            r.ImGui_DrawList_AddRectFilledMultiColor(WDL, L, T, R, B, BgClrA, BgClrA, DefClr_B,
                DefClr_B)

            r.ImGui_SameLine(ctx, nil, 0)

            if isActive then
                local _, v = r.ImGui_GetMouseDelta(ctx, nil, nil)
                if Mods == Shift then DrgSpdMod = 4 end
                DraggingMorph = FxGUID
                FX[FxGUID].MorphAB_Sldr = SetMinMax(
                    (FX[FxGUID].MorphAB_Sldr or 0) + v / (DrgSpdMod or 2), 0, 100)
                SldrActClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_SliderGrabActive())
                if FX[FxGUID].MorphB[1] ~= nil then
                    local M_ID
                    if FX[FxGUID].Morph_ID then
                        r.TrackFX_SetParamNormalized(LT_Track, 0 --[[Macro.jsfx]],
                            7 + FX[FxGUID].Morph_ID, FX[FxGUID].MorphAB_Sldr / 100)
                    else
                        for i, v in ipairs(FX[FxGUID].MorphA), FX[FxGUID].MorphA, -1 do
                            if v ~= FX[FxGUID].MorphB[i] then
                                if FX[FxGUID].PrmList[i] then
                                    if FX[FxGUID].PrmList[i].BL ~= true then
                                        Fv = v +
                                            (FX[FxGUID].MorphB[i] - v) *
                                            (FX[FxGUID].MorphAB_Sldr / 100)
                                        r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, i, Fv)
                                    end
                                else
                                    Fv = v + (FX[FxGUID].MorphB[i] - v) *
                                        (FX[FxGUID].MorphAB_Sldr / 100)
                                    r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, i, Fv)
                                end
                            end
                        end
                    end
                end
            end

            --[[ if ifHvr   then

                --r.ImGui_SetNextWindowPos(ctx,SCx+20, SCy+20)
                r.ImGui_OpenPopup(ctx, 'Hover On Preset Morph Drag')

                M.JustHvrd = true
            end
            if M.JustHvrd then

                M.JustHvrd = nil
            end ]]

            if r.ImGui_BeginPopup(ctx, 'Morphing menu' .. FX_Idx) then
                local Disable
                MorphingMenuOpen = true
                if not FX[FxGUID].MorphA[1] or not FX[FxGUID].MorphB[1] then
                    r.ImGui_BeginDisabled(ctx)
                end

                if not FX[FxGUID].Morph_ID or FX[FxGUID].Unlink then
                    if r.ImGui_Selectable(ctx, 'Automate', false) then
                        r.gmem_attach('ParamValues')

                        if not Trk[TrkID].Morph_ID then
                            Trk[TrkID].Morph_ID = {} -- Morph_ID is the CC number jsfx sends
                            Trk[TrkID].Morph_ID[1] = FxGUID
                            FX[FxGUID].Morph_ID = 1
                        else
                            if not FX[FxGUID].Morph_ID then
                                table.insert(Trk[TrkID].Morph_ID, FxGUID)
                                FX[FxGUID].Morph_ID = tablefind(Trk[TrkID].Morph_ID, FxGUID)
                            end
                        end

                        if --[[Add Macros JSFX if not found]] r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) == -1 and r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) == -1 then
                            r.gmem_write(1, PM.DIY_TrkID[TrkID]) --gives jsfx a guid when it's being created, this will not change becuase it's in the @init.
                            AddMacroJSFX()
                        end
                        for i, v in ipairs(FX[FxGUID].MorphA), FX[FxGUID].MorphA, -1 do
                            local Scale = FX[FxGUID].MorphB[i] - v

                            if v ~= FX[FxGUID].MorphB[i] then
                                local function LinkPrm()
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.active", 1)   -- 1 active, 0 inactive
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.scale", Scale)   -- Scale
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.effect", -100) -- -100 enables midi_msg*
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.param", -1)   -- -1 not parameter link
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg", 160)   -- 160 is Aftertouch
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".mod.baseline", v) -- Baseline                                                           
                                    FX[FxGUID][i] = FX[FxGUID][i] or {}
                                    r.GetSetMediaTrackInfo_String(LT_Track,
                                        'P_EXT: FXs Morph_ID' .. FxGUID, FX[FxGUID].Morph_ID, true)
                                end

                                if FX[FxGUID].PrmList[i] then
                                    if FX[FxGUID].PrmList[i].BL ~= true then
                                        LinkPrm()
                                    end
                                else
                                    LinkPrm()
                                end
                            end
                        end


                        -- Show Envelope for Morph Slider
                        local env = r.GetFXEnvelope(LT_Track, 0, 7 + FX[FxGUID].Morph_ID, false) -- Check if envelope is on
                        if env == nil then  -- Envelope is off
                            local env = r.GetFXEnvelope(LT_Track, 0, 7 + FX[FxGUID].Morph_ID, true) -- true = Create envelope
                        else -- Envelope is on but invisible
                            local rv, EnvelopeStateChunk = r.GetEnvelopeStateChunk(env, "", false)
                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 0", "VIS 1")
                            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
                        end
                        r.TrackList_AdjustWindows(false)
                        r.UpdateArrange()

                        FX[FxGUID].Unlink = false
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FXs Morph_ID' .. FxGUID .. 'Unlink', '', true)

                        SetPrmAlias(LT_TrackNum, 1, 8 + FX[FxGUID].Morph_ID,
                            FX.Win_Name_S[FX_Idx]:gsub("%b()", "") .. ' - Morph AB ')
                            
                    end
                elseif FX[FxGUID].Morph_ID or not FX[FxGUID].Unlink then
                    if r.ImGui_Selectable(ctx, 'Unlink Parameters to Morph Automation', false) then
                        for i, v in ipairs(FX[FxGUID].MorphA), FX[FxGUID].MorphA, -1 do
                            local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..i..".plink.active", 0)   -- 1 active, 0 inactive
                        end
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FXs Morph_ID' .. FxGUID,
                            FX[FxGUID].Morph_ID, true)
                        FX[FxGUID].Unlink = true
                        r.GetSetMediaTrackInfo_String(LT_Track,
                            'P_EXT: FXs Morph_ID' .. FxGUID .. 'Unlink', 'Unlink', true)
                    end
                end

                if FX[FxGUID].Morph_Value_Edit then
                    if r.ImGui_Selectable(ctx, 'EXIT Edit Preset Value Mode', false) then
                        FX[FxGUID].Morph_Value_Edit = false
                    end
                else
                    if Disable then r.ImGui_BeginDisabled(ctx) end
                    if r.ImGui_Selectable(ctx, 'ENTER Edit Preset Value Mode', false) then
                        FX[FxGUID].Morph_Value_Edit = true
                    end
                end
                if not FX[FxGUID].MorphA[1] or not FX[FxGUID].MorphB[1] then r.ImGui_EndDisabled(ctx) end

                if r.ImGui_Selectable(ctx, 'Morphing Blacklist Settings', false) then
                    if OpenMorphSettings then
                        OpenMorphSettings = FxGUID
                    else
                        OpenMorphSettings =
                            FxGUID
                    end
                    local Ct = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                    FX[FxGUID].PrmList = FX[FxGUID].PrmList or {}
                    for i = 0, Ct - 4, 1 do --get param names
                        FX[FxGUID].PrmList[i]      = FX[FxGUID].PrmList[i] or {}
                        local rv, name             = r.TrackFX_GetParamName(LT_Track, FX_Idx,
                            i)
                        FX[FxGUID].PrmList[i].Name = name
                    end
                end

                if r.ImGui_Selectable(ctx, 'Hide Morph Slider', false) then
                    FX[FxGUID].MorphHide = true
                    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX Morph Hide' .. FxGUID,
                        'true',true)
                end
                
                r.ImGui_EndPopup(ctx)
            else
                MorphingMenuOpen = false
            end




            if not ifHvr and M.JustHvrd then
                M.timer = M.timer + 1
            else
                M.timer = 0
            end





            V_Pos = T + (FX[FxGUID].MorphAB_Sldr or 0) / 100 * H * 0.95
            r.ImGui_DrawList_AddRectFilled(WDL, L, V_Pos, R, V_Pos + 10, 0xffffff22)
            r.ImGui_DrawList_AddRect(WDL, L, V_Pos, R, V_Pos + 10, 0xffffff44)


            r.ImGui_SameLine(ctx)
            r.ImGui_SetCursorPos(ctx, x, y + 200)
            if not FX[FxGUID].MorphB[1] then
                BtnB_TxtClr = r.ImGui_GetStyleColor(ctx,
                    r.ImGui_Col_TextDisabled())
            end

            if BtnB_TxtClr then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                    r.ImGui_GetStyleColor(ctx, r.ImGui_Col_TextDisabled()))
            end
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), DefClr_B)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), DefClr_B_Hvr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), DefClr_B_Act)

            if r.ImGui_Button(ctx, 'B##' .. FxGUID, 20, 20) then
                StoreAllPrmVal('B', nil, FX[FxGUID].Morph_ID)
                local rv, presetname = r.TrackFX_GetPreset(LT_Track, FX_Idx)
                if rv then FX[FxGUID].MorphB_Name = presetname end
            end
            if r.ImGui_IsItemHovered(ctx) and FX[FxGUID].MorphB_Name then
                HintToolTip(FX[FxGUID]
                    .MorphB_Name)
            end
            r.ImGui_PopStyleColor(ctx, 3)

            if BtnB_TxtClr then r.ImGui_PopStyleColor(ctx) end
            if FX.Enable[FX_Idx] == false then
                r.ImGui_DrawList_AddRectFilled(WDL, L, T - 20, R, B +20, 0x00000088)
            end

            r.ImGui_SetCursorPos(ctx, OrigCurX + 19, OrigCurY)
        end

        local FX_Devices_Bg = FX_Devices_Bg

        -- FX window color

        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), FX[FxGUID].BgClr or FX_Devices_Bg or 0x151515ff); local poptimes = 1


        FX[FxGUID] = FX[FxGUID] or {}

        local PrmCount = tonumber(select(2, r.GetProjExtState(0, 'FX Devices', 'Prm Count' .. FxGUID))) or 0
        local Def_Sldr_W = 160
        if FX.Def_Sldr_W[FxGUID] then Def_Sldr_W = FX.Def_Sldr_W[FxGUID] end

        if FX.Def_Type[FxGUID] == 'Slider' or FX.Def_Type[FxGUID] == 'Drag' or not FX.Def_Type[FxGUID] then
            local DF = (FX.Def_Sldr_W[FxGUID] or Df.Sldr_W)

            local Ct = math.max(math.floor((PrmCount / 6 - 0.01)) + 1, 1)

            DefaultWidth = (DF + GapBtwnPrmColumns) * Ct
        elseif FX.Def_Type[FxGUID] == 'Knob' then
            local Ct = math.max(math.floor((PrmCount / 3) - 0.1) + 1, 1) -- need to -0.1 so flooring 3/3 -0.1 will return 0 and 3/4 -0.1 will be 1
            DefaultWidth = Df.KnobSize * Ct + GapBtwnPrmColumns
        end

        if FindStringInTable(BlackListFXs, FX_Name) then
            Hide = true
        end

        if Trk[TrkID].PreFX_Hide then
            if FindStringInTable(Trk[TrkID].PreFX, FxGUID) then
                Hide = true
            end
            if Trk[TrkID].PreFX[FX_Idx + 1] == FxGUID then
                Hide = true
            end
        end
        if not Hide then
            local CurPosX
            if FxGUID == FXGUID[(tablefind(Trk[TrkID].PostFX, FxGUID) or 0) - 1] then
                --[[ CurPosX = r.ImGui_GetCursorPosX(ctx)
                r.ImGui_SetCursorPosX(ctx,VP.X+VP.w- (FX[FxGUID].PostWin_SzX or 0)) ]]
            end
            local Width = FX.WidthCollapse[FxGUID] or FX[FxGUID].Width or DefaultWidth or 220
            local winFlg = r.ImGui_WindowFlags_NoScrollWithMouse() + r.ImGui_WindowFlags_NoScrollbar() 
            local dummyH = 220
            if FX_Name == 'Container' then  
                winFlg = FX[FxGUID].NoScroll or  r.ImGui_WindowFlags_AlwaysAutoResize()
                dummyH =0

            end
            r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ScrollbarSize(), 8) -- styleVar ScrollBar



            if r.ImGui_BeginChild(ctx, FX_Name .. FX_Idx, Width, 220,nil, winFlg) and not Hide then ----START CHILD WINDOW------
                if Draw[FxNameS] ~= nil then
                    local D = Draw[FxNameS]
                end


                Glob.FDL = r.ImGui_GetForegroundDrawList(ctx)

                WDL = r.ImGui_GetWindowDrawList(ctx)
                Win_L, Win_T = r.ImGui_GetItemRectMin(ctx); Win_W, Win_H = r.ImGui_GetItemRectSize(ctx)
                Win_R, _ = r.ImGui_GetItemRectMax(ctx); Win_B = Win_T + 220

                if Draw.DrawMode[FxGUID] == true then
                    local D = Draw[FxNameS]
                    r.ImGui_DrawList_AddRectFilled(WDL, Win_L, Win_T, Win_R, Win_B, 0x00000033)
                    -- add horizontal grid
                    for i = 0, 220, LE.GridSize do 
                        r.ImGui_DrawList_AddLine(WinDrawList, Win_L, Win_T + i, Win_R, Win_T + i, 0x44444411)
                    end
                    -- add vertical grid
                    for i = 0, FX[FxGUID].Width or DefaultWidth, LE.GridSize do
                        r.ImGui_DrawList_AddLine(WinDrawList, Win_L + i, Win_T, Win_L + i, Win_B, 0x44444411)
                    end
                    if r.ImGui_IsMouseHoveringRect(ctx, Win_L, Win_T, Win_R, Win_B) and HvringItmSelector == nil and not Draw.SelItm and Draw.Time == 0 then
                        if Draw.Type == 'Text' then
                            r.ImGui_SetMouseCursor(ctx,r.ImGui_MouseCursor_TextInput())
                        end
                        if r.ImGui_IsMouseClicked(ctx, 0) and Mods == 0 then
                            Draw.CurrentylDrawing = true
                            MsX_Start, MsY_Start = r.ImGui_GetMousePos(ctx);
                            CurX, CurY = r.ImGui_GetCursorScreenPos(ctx)
                            Win_MsX_Start = MsX_Start - CurX; Win_MsY_Start = MsY_Start - CurY + 3
                        end

                        if Draw.CurrentylDrawing then
                            if IsLBtnHeld and Mods == 0 and MsX_Start then
                                MsX, MsY   = r.ImGui_GetMousePos(ctx)
                                CurX, CurY = r.ImGui_GetCursorScreenPos(ctx)
                                Win_MsX    = MsX - CurX; Win_MsY = MsY - CurY

                                Rad        = MsX - MsX_Start
                                local Clr = Draw.clr or 0xffffffff
                                if Rad < 0 then Rad = Rad * (-1) end
                                if Draw.Type == 'line' then
                                    r.ImGui_DrawList_AddLine(WDL, MsX_Start, MsY_Start, MsX, MsY_Start, Clr)
                                elseif Draw.Type == 'V-line' then
                                    r.ImGui_DrawList_AddLine(WDL, MsX_Start, MsY_Start, MsX_Start, MsY, Clr)
                                elseif Draw.Type == 'rectangle' then
                                    r.ImGui_DrawList_AddRect(WDL, MsX_Start, MsY_Start, MsX, MsY, Clr, FX[FxGUID].Draw.Df_EdgeRound or 0)
                                elseif Draw.Type == 'Picture' then
                                    r.ImGui_DrawList_AddRect(WDL, MsX_Start, MsY_Start, MsX, MsY, Clr, FX[FxGUID].Draw.Df_EdgeRound or 0)
                                elseif Draw.Type == 'rect fill' then
                                    r.ImGui_DrawList_AddRectFilled(WDL, MsX_Start, MsY_Start, MsX, MsY, Clr, FX[FxGUID].Draw.Df_EdgeRound or 0)
                                elseif Draw.Type == 'circle' then
                                    r.ImGui_DrawList_AddCircle(WDL, MsX_Start, MsY_Start, Rad, Clr)
                                elseif Draw.Type == 'circle fill' then
                                    r.ImGui_DrawList_AddCircleFilled(WDL, MsX_Start, MsY_Start, Rad, Clr)
                                elseif Draw.Type == 'Text' then
                                    r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_TextInput())
                                end
                            end

                            if r.ImGui_IsMouseReleased(ctx, 0) and Mods == 0 and Draw.Type ~= 'Text' then
                                FX[FxGUID].Draw[(#FX[FxGUID].Draw or 0) + 1] =  {}
                                local D = FX[FxGUID].Draw[(#FX[FxGUID].Draw or 1)]


                                LE.BeenEdited = true
                                --find the next available slot in table

                                if Draw.Type == 'circle' or Draw.Type == 'circle fill' then
                                    D.R =  Rad
                                else
                                    D.R =  Win_MsX
                                end

                                D.L =  Win_MsX_Start
                                D.T =  Win_MsY_Start
                                D.Type =  Draw.Type
                                D.B =  Win_MsY
                                D.clr =  Draw.clr or 0xffffffff
                                --if not Draw.SelItm then Draw.SelItm = #D.Type end
                            end




                            if Draw.Type == 'Text' and IsLBtnClicked and Mods == 0 then
                                AddText = #D.Type + 1
                            end
                        end
                    end
                    HvringItmSelector = nil
                    if AddText then
                        r.ImGui_OpenPopup(ctx, 'Drawlist Add Text Menu')
                    end

                    if r.ImGui_BeginPopup(ctx, 'Drawlist Add Text Menu') then
                        r.ImGui_SetKeyboardFocusHere(ctx)

                        enter, NewDrawTxt = r.ImGui_InputText(ctx, '##' .. 'DrawTxt', NewDrawTxt)
                        --r.ImGui_SetItemDefaultFocus( ctx)

                        if r.ImGui_IsWindowAppearing(ctx) then
                            table.insert(D.L, Win_MsX_Start);
                            table.insert(D.T, Win_MsY_Start);;
                            table.insert(D.Type, Draw.Type)
                            table.insert(D.B, Win_MsY)
                            table.insert(D.clr, Draw.clr)
                        end


                        if AddText then
                            D.Txt[AddText] = NewDrawTxt
                        end

                        if r.ImGui_IsItemDeactivatedAfterEdit(ctx) then
                            D.Txt[#D.Txt] = NewDrawTxt
                            AddText = nil;
                            NewDrawTxt = nil



                            r.ImGui_CloseCurrentPopup(ctx)
                        end

                        r.ImGui_SetItemDefaultFocus(ctx)



                        r.ImGui_EndPopup(ctx)
                    end
                    if LBtnRel then Draw.CurrentylDrawing = nil end

                    if r.ImGui_IsMouseHoveringRect(ctx, Win_L, Win_T, Win_R, Win_B) and HvringItmSelector == nil then
                        if IsLBtnClicked then
                            Draw.SelItm = nil
                            Draw.Time = 1
                        end
                    end
                    if Draw.Time > 0 then Draw.Time = Draw.Time + 1 end
                    if Draw.Time > 6 then Draw.Time = 0 end

                    if FX[FxGUID].Draw then
                        for i, D in ipairs(FX[FxGUID].Draw) do
                            local ID = FX_Name .. i
                            local CircleX, CircleY = Win_L + D.L , Win_T + D.T
                            local FDL = r.ImGui_GetForegroundDrawList(ctx)
                            r.ImGui_DrawList_AddCircle(FDL, CircleX, CircleY, 7, 0x99999999)
                            r.ImGui_DrawList_AddText(FDL, Win_L + D.L - 2, Win_T + D.T - 7, 0x999999ff, i)


                            if Draw.SelItm == i then
                                r.ImGui_DrawList_AddCircleFilled(WDL, CircleX, CircleY, 7, 0x99999955)
                            end


                            --if hover on item node ...
                            if r.ImGui_IsMouseHoveringRect(ctx, CircleX - 5, CircleY - 5, CircleX + 5, CircleY + 10) then
                                HvringItmSelector = true
                                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
                                if DragItm == nil then
                                    r.ImGui_DrawList_AddCircle(WDL, CircleX, CircleY, 9, 0x999999ff)
                                end
                                if IsLBtnClicked and Mods == 0 then
                                    Draw.SelItm = i
                                    DragItm = i
                                end


                                if IsLBtnClicked and Mods == Alt then
                                    table.remove(D.Type, i)
                                    table.remove(D.L, i)
                                    table.remove(D.R, i)
                                    table.remove(D.T, i)
                                    table.remove(D.B, i)
                                    if D.Txt then table.remove(D.Txt, SetMinMax(i, 1, #D.Txt)) end
                                    if D.clr then table.remove(D.clr, SetMinMax(i, 1, #D.clr)) end
                                    if r.ImGui_BeginPopup(ctx, 'Drawlist Add Text Menu') then
                                        r.ImGui_CloseCurrentPopup(ctx)
                                        r.ImGui_EndPopup(ctx)
                                    end
                                end
                            end

                            if not IsLBtnHeld then DragItm = nil end
                            if LBtnDrag and DragItm == i then --- Drag node to reposition
                                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
                                r.ImGui_DrawList_AddCircleFilled(WDL, CircleX, CircleY, 7, 0x00000033)
                                local Dx, Dy = r.ImGui_GetMouseDelta(ctx)
                                if D.Type[DragItm] ~= 'circle' and D.Type[DragItm] ~= 'circle fill' then
                                    D.R = D.R + Dx -- this is circle's radius
                                end
                                D.L = D.L + Dx
                                D.T = D.T + Dy
                                D.B = D.B + Dy
                            end
                        end
                    end
                end --- end of if draw mode is active

                if FX[FxGUID].Draw and not FX[FxGUID].Collapse then

                    for i, Type in ipairs(FX[FxGUID].Draw) do
                        FX[FxGUID].Draw[i] = FX[FxGUID].Draw[i] or {}
                        local D = FX[FxGUID].Draw[i]
                        local L = Win_L + D.L
                        local T = Win_T + D.T
                        local R = Win_L + (D.R or 0)
                        local B = Win_T + D.B
                        local Round = FX[FxGUID].Draw.Df_EdgeRound or 0

                        if D.Type == 'line' then
                            r.ImGui_DrawList_AddLine(WDL, L, T, R, T, D.clr or 0xffffffff)
                        elseif D.Type == 'V-line' then
                            r.ImGui_DrawList_AddLine(WDL, Win_L + D.L, Win_T + D.T,
                                Win_L + D.L, Win_T + D.B, D.clr or 0xffffffff)
                        elseif D.Type == 'rectangle' then
                            r.ImGui_DrawList_AddRect(WDL, L, T, R, B, D.clr or 0xffffffff, Round)
                        elseif D.Type == 'rect fill' then
                            r.ImGui_DrawList_AddRectFilled(WDL, L, T, R, B, D.clr or 0xffffffff,
                                Round)
                        elseif D.Type == 'circle' then
                            r.ImGui_DrawList_AddCircle(WDL, L, T, D.R, D.clr or 0xffffffff)
                        elseif D.Type == 'circle fill' then
                            r.ImGui_DrawList_AddCircleFilled(WDL, L, T, D.R,
                                D.clr or 0xffffffff)
                        elseif D.Type == 'Text' and D.Txt then
                            r.ImGui_DrawList_AddTextEx(WDL, D.Font or Font_Andale_Mono_13,
                                D.FtSize or 13, L, T, D.clr or 0xffffffff, D.Txt)
                        elseif D.Type == 'Picture' then
                            if not D.Image then
                                r.ImGui_DrawList_AddRectFilled(WDL, L, T, R, B, 0xffffff33, Round)
                                r.ImGui_DrawList_AddTextEx(WDL, nil, 12, L, T + (B - T) / 2,
                                    0xffffffff, 'Add Image path', R - L)
                            else
                                if D.KeepImgRatio then
                                    local w, h = r.ImGui_Image_GetSize(D.Image)

                                    local H_ratio = w / h
                                    local size = R - L


                                    r.ImGui_DrawList_AddImage(WDL, D.Image, L, T, L + size,
                                        T + size * H_ratio, 0, 0, 1, 1, D.clr or 0xffffffff)
                                else
                                    r.ImGui_DrawList_AddImageQuad(WDL, D.Image, L, T, R, T, R, B,
                                        L, B,
                                        _1, _2, _3, _4, _5, _6, _7, _8, D.clr or 0xffffffff)
                                end
                            end
                            -- ImageAngle(ctx, Image, 0, R - L, B - T, L, T)
                        end
                    end
                end

                if FX.LayEdit == FxGUID and Draw.DrawMode[FxGUID] ~= true and Mods ~= Apl then -- Resize FX or title btn
                    MouseX, MouseY = r.ImGui_GetMousePos(ctx)
                    Win_L, Win_T = r.ImGui_GetItemRectMin(ctx)
                    Win_R, _ = r.ImGui_GetItemRectMax(ctx); Win_B = Win_T + 220
                    WinDrawList = r.ImGui_GetWindowDrawList(ctx)
                    r.ImGui_DrawList_AddRectFilled(WinDrawList, Win_L or 0, Win_T or 0, Win_R or 0,
                        Win_B, 0x00000055)
                    --draw grid

                    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Equal()) then
                        LE.GridSize = LE.GridSize + 5
                    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Minus()) then
                        LE.GridSize = LE.GridSize - 5
                    end

                    for i = 0, FX[FXGUID[FX_Idx]].Width or DefaultWidth, LE.GridSize do
                        r.ImGui_DrawList_AddLine(WinDrawList, Win_L + i, Win_T, Win_L + i, Win_B, 0x44444455)
                    end
                    for i = 0, 220, LE.GridSize do
                        r.ImGui_DrawList_AddLine(WinDrawList, Win_L,
                            Win_T + i, Win_R, Win_T + i, 0x44444455)
                    end

                    r.ImGui_DrawList_AddLine(WinDrawList, Win_R - 3, Win_T, Win_R - 3, Win_B,
                        0x66666677, 1)


                    if r.ImGui_IsMouseHoveringRect(ctx, Win_R - 5, Win_T, Win_R + 5, Win_B) then
                        r.ImGui_DrawList_AddLine(WinDrawList, Win_R - 3, Win_T, Win_R - 3, Win_B,
                            0xffffffff, 3)
                        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())

                        if IsLBtnClicked then
                            LE.ResizingFX = FX_Idx --@Todo change fxidx to fxguid
                        end
                    end


                    if LE.ResizingFX == FX_Idx and IsLBtnHeld then
                        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())

                        r.ImGui_DrawList_AddRectFilled(WinDrawList, Win_L or 0, Win_T or 0,
                            Win_R or 0, Win_B, 0x00000055)
                        local MsDragDeltaX, MsDragDeltaY = r.ImGui_GetMouseDragDelta(ctx); local Dx, Dy =
                            r.ImGui_GetMouseDelta(ctx)
                        if not FX[FxGUID].Width then FX[FxGUID].Width = DefaultWidth end
                        FX[FxGUID].Width = FX[FxGUID].Width + Dx; LE.BeenEdited = true
                    end
                    if not IsLBtnHeld then LE.ResizingFX = nil end
                end


                if FX.Enable[FX_Idx] == nil then
                    FX.Enable[FX_Idx] = r.TrackFX_GetEnabled(LT_Track, FX_Idx)
                end

                r.ImGui_SameLine(ctx, nil, 0)
                if FX.LayEdit == FxGUID and Draw.DrawMode[FxGUID] ~= true then
                    r.ImGui_BeginDisabled(ctx); R, T = r.ImGui_GetItemRectMax(ctx)
                end

                
                


                AddWindowBtn (FxGUID, FX_Idx)


                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Border(), getClr(r.ImGui_Col_FrameBg()))


                -- Add Prm popup
                PrmFilter = r.ImGui_CreateTextFilter(PrmFilterTxt)
                if r.ImGui_BeginPopup(ctx, 'Add Parameter' .. FxGUID, r.ImGui_WindowFlags_AlwaysVerticalScrollbar()) then
                    local CheckBox, rv = {}, {}
                    if r.ImGui_Button(ctx, 'Add all parameters', -1) then
                        for i = 0, r.TrackFX_GetNumParams(LT_Track, FX_Idx) - 1, 1 do
                            local P_Name = select(2, r.TrackFX_GetParamName(LT_Track, FX_Idx, i))

                            if not FX[FxGUID][i + 1] then
                                StoreNewParam(FxGUID, P_Name, i, FX_Idx, true)
                            else
                                local RptPrmFound
                                for I = 1, #FX[FxGUID], 1 do
                                    if FX[FxGUID][I].Num == i then RptPrmFound = true end
                                end

                                if not RptPrmFound then
                                    StoreNewParam(FxGUID, P_Name, i, FX_Idx, true)
                                    SyncTrkPrmVtoActualValue()
                                end
                            end
                        end
                    end


                    AddPrmPopupOpen = FxGUID
                    if not PrmFilterTxt then AddPrmWin_W, AddPrmWin_H = r.ImGui_GetWindowSize(ctx) end
                    r.ImGui_SetWindowSize(ctx, 500, 500, condIn)

                    local Ct = r.TrackFX_GetNumParams(LT_Track, FX_Idx)


                    r.ImGui_SetNextItemWidth(ctx, 60)

                    if not FX[FxGUID].NotFirstOpenPrmWin then
                        r.ImGui_SetKeyboardFocusHere(ctx, offsetIn)
                    end

                    if r.ImGui_TextFilter_Draw(PrmFilter, ctx, '##PrmFilterTxt', -1 - (SpaceForBtn or 0)) then
                        PrmFilterTxt = r.ImGui_TextFilter_Get(PrmFilter)
                        r.ImGui_TextFilter_Set(PrmFilter, PrmFilterTxt)
                    end

                    for i = 1, Ct, 1 do
                        if FX[FxGUID][i] then
                            CheckBox[FX[FxGUID][i].Num] = true
                        end
                    end

                    for i = 1, Ct, 1 do
                        local P_Name = select(2,
                            r.TrackFX_GetParamName(LT_Track, FX_Idx, i - 1))
                        if r.ImGui_TextFilter_PassFilter(PrmFilter, P_Name) then
                            rv[i], CheckBox[i - 1] = r.ImGui_Checkbox(ctx, (i - 1) .. '. ' .. P_Name,
                                CheckBox[i - 1])
                            if rv[i] then
                                local RepeatPrmFound

                                for I = 1, Ct, 1 do
                                    if FX[FxGUID][I] then
                                        if FX[FxGUID][I].Num == i - 1 then RepeatPrmFound = I end
                                    end
                                end
                                if RepeatPrmFound then
                                    DeletePrm(FxGUID, RepeatPrmFound, FX_Idx)
                                else
                                    StoreNewParam(FxGUID, P_Name, i - 1, FX_Idx, true)
                                    SyncTrkPrmVtoActualValue()
                                end
                            end
                        end
                    end
                    FX[FxGUID].NotFirstOpenPrmWin = true
                    r.ImGui_EndPopup(ctx)
                elseif AddPrmPopupOpen == FxGUID then
                    PrmFilterTxt = nil
                    FX[FxGUID].NotFirstOpenPrmWin = nil
                end


                r.ImGui_PopStyleColor(ctx)


                if FX.LayEdit == FxGUID and Draw.DrawMode[FxGUID] ~= true then
                    local L, T = r.ImGui_GetItemRectMin(ctx); local R, _ = r.ImGui_GetItemRectMax(
                        ctx); B = T + 20
                    r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, T + 10, 3, 0x999999ff)
                    r.ImGui_DrawList_AddRect(WinDrawList, L, T, R, T + 20, 0x999999ff)

                    if MouseX > L and MouseX < R and MouseY > T and MouseY < B then
                        r.ImGui_DrawList_AddRectFilled(WinDrawList, L, T, R, T + 20, 0x99999955)
                        if IsLBtnClicked then
                            LE.SelectedItem = 'Title'
                            LE.ChangingTitleSize = true
                            LE.MouseX_before, _ = r.ImGui_GetMousePos(ctx)
                        elseif IsRBtnClicked then
                            r.ImGui_OpenPopup(ctx, 'Fx Module Menu')
                        end
                    end

                    if LE.SelectedItem == 'Title' then
                        r.ImGui_DrawList_AddRect(WinDrawList, L, T, R,
                            T + 20, 0x999999ff)
                    end

                    if MouseX > R - 5 and MouseX < R + 5 and MouseY > T and MouseY < B then --if hover on right edge
                        if IsLBtnClicked then LE.ChangingTitleSize = true end
                    end

                    if LBtnDrag and LE.ChangingTitleSize then
                        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())
                        DeltaX, DeltaY = r.ImGui_GetMouseDelta(ctx)
                        local AddedDelta = AddedDelta or 0 + DeltaX
                        LE.MouseX_after, _ = r.ImGui_GetMousePos(ctx)
                        local MouseDiff = LE.MouseX_after - LE.MouseX_before

                        if FX[FxGUID].TitleWidth == nil then
                            FX[FxGUID].TitleWidth = DefaultWidth - 30
                        end
                        if Mods == 0 then
                            if MouseDiff > LE.GridSize then
                                FX[FxGUID].TitleWidth = FX[FxGUID].TitleWidth + LE.GridSize; LE.MouseX_before =
                                    r.ImGui_GetMousePos(ctx); LE.BeenEdited = true
                            elseif MouseDiff < -LE.GridSize then
                                FX[FxGUID].TitleWidth = FX[FxGUID].TitleWidth - LE.GridSize; LE.MouseX_before =
                                    r.ImGui_GetMousePos(ctx); LE.BeenEdited = true
                            end
                        end
                        if Mods == Shift then
                            FX[FxGUID].TitleWidth = FX[FxGUID].TitleWidth + DeltaX; LE.BeenEdited = true
                        end
                    end
                    if IsLBtnHeld == false then LE.ChangingTitleSize = nil end

                    r.ImGui_EndDisabled(ctx)
                end








                if DebugMode and r.ImGui_IsItemHovered(ctx) then tooltip('FX_Idx = '..FX_Idx) end
                if DebugMode and r.ImGui_IsKeyDown(ctx, 84) then tooltip(TrkID) end





                --r.Undo_OnStateChangeEx(string descchange, integer whichStates, integer trackparm) -- @todo Detect FX deletion






                if r.ImGui_BeginPopup(ctx, 'Fx Module Menu') then
                    if not FX[FxGUID].MorphA then
                        if r.ImGui_Button(ctx, 'Preset Morphing', 160) then
                            FX[FxGUID].MorphA = {}
                            FX[FxGUID].MorphB = {}
                            local PrmCount = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                            for i = 0, PrmCount - 4, 1 do
                                local Prm_Val, minval, maxval = r.TrackFX_GetParamNormalized(
                                    LT_Track, FX_Idx, i)
                                FX[FxGUID].MorphA[i] = Prm_Val
                                r.GetSetMediaTrackInfo_String(LT_Track,
                                    'P_EXT: FX Morph A' .. i .. FxGUID, Prm_Val, true)
                            end
                            RestoreBlacklistSettings(FxGUID, FX_Idx, LT_Track, PrmCount)
                            --[[ r.SetProjExtState(r0oj, 'FX Devices', string key, string value) ]]
                            FX[FxGUID].MorphHide = nil
                            r.ImGui_CloseCurrentPopup(ctx)
                        end
                    else
                        if not FX[FxGUID].MorphHide then
                            if r.ImGui_Button(ctx, 'Hide Morph Slider', 160) then
                                FX[FxGUID].MorphHide = true
                                r.GetSetMediaTrackInfo_String(LT_Track,
                                    'P_EXT: FX Morph Hide' .. FxGUID, 'true', true)
                                r.ImGui_CloseCurrentPopup(ctx)
                            end
                        else
                            if r.ImGui_Button(ctx, 'Show Morph Slider', 160) then
                                FX[FxGUID].MorphHide = nil
                                r.ImGui_CloseCurrentPopup(ctx)
                            end
                        end
                    end

                    r.ImGui_SameLine(ctx)
                    if not FX[FxGUID].MorphA then
                        r.ImGui_BeginDisabled(ctx)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                            getClr(r.ImGui_Col_TextDisabled()))
                    end
                    if IconBtn(20, 20, 'Y') then -- settings icon
                        if OpenMorphSettings then
                            OpenMorphSettings = FxGUID
                        else
                            OpenMorphSettings =
                                FxGUID
                        end
                        local Ct = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                        FX[FxGUID].PrmList = FX[FxGUID].PrmList or {}
                        for i = 0, Ct - 4, 1 do --get param names
                            FX[FxGUID].PrmList[i]      = FX[FxGUID].PrmList[i] or {}
                            local rv, name             = r.TrackFX_GetParamName(LT_Track,
                                FX_Idx, i)
                            FX[FxGUID].PrmList[i].Name = name
                        end
                        r.ImGui_CloseCurrentPopup(ctx)
                    end
                    if not FX[FxGUID].MorphA then
                        r.ImGui_EndDisabled(ctx)
                        r.ImGui_PopStyleColor(ctx)
                    end



                    if r.ImGui_Button(ctx, 'Layout Edit mode', -FLT_MIN) then
                        if not FX.LayEdit then
                            FX.LayEdit = FxGUID
                        else
                            FX.LayEdit = false
                        end
                        CloseLayEdit = nil
                        r.ImGui_CloseCurrentPopup(ctx)
                        if Draw.DrawMode[FxGUID] then Draw.DrawMode[FxGUID] = nil end
                    end


                    if r.ImGui_Button(ctx, 'Save all values as default', -FLT_MIN) then
                        local dir_path = CurrentDirectory .. 'src'
                        local file_path = ConcatPath(dir_path, 'FX Default Values.ini')
                        local file = io.open(file_path, 'a+')

                        if file then
                            local FX_Name = ChangeFX_Name(FX_Name)
                            Content = file:read('*a')
                            local Ct = Content

                            local pos = Ct:find(FX_Name)
                            if pos then
                                file:seek('set', pos - 1)
                            else
                                file:seek('end')
                            end

                            file:write(FX_Name, '\n')
                            local PrmCount = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                            PrmCount = PrmCount - 4
                            file:write('Number of Params: ', PrmCount, '\n')

                            local function write(i, name, Value)
                                file:write(i, '. ', name, ' = ', Value or '', '\n')
                            end

                            for i = 0, PrmCount, 1 do
                                local V = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, i)
                                local _, N = r.TrackFX_GetParamName(LT_Track, FX_Idx, i)
                                write(i, N, V)
                            end

                            file:write('\n')


                            file:close()
                        end
                        r.ImGui_CloseCurrentPopup(ctx)
                    end



                    if FX.Def_Type[FxGUID] ~= 'Knob' then
                        r.ImGui_Text(ctx, 'Default Sldr Width:')
                        r.ImGui_SameLine(ctx)
                        local SldrW_DrgSpd
                        if Mods == Shift then SldrW_DrgSpd = 1 else SldrW_DrgSpd = LE.GridSize end
                        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)


                        Edited, FX.Def_Sldr_W[FxGUID] = r.ImGui_DragInt(ctx,
                            '##' .. FxGUID .. 'Default Width', FX.Def_Sldr_W[FxGUID] or 160,
                            LE.GridSize, 50, 300)


                        if Edited then
                            r.SetProjExtState(0, 'FX Devices',
                                'Default Slider Width for FX:' .. FxGUID, FX.Def_Sldr_W[FxGUID])
                        end
                    end



                    r.ImGui_Text(ctx, 'Default Param Type:')
                    r.ImGui_SameLine(ctx)
                    r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)


                    if r.ImGui_BeginCombo(ctx, '## P type', FX.Def_Type[FxGUID] or 'Slider', r.ImGui_ComboFlags_NoArrowButton()) then
                        if r.ImGui_Selectable(ctx, 'Slider', false) then
                            FX.Def_Type[FxGUID] = 'Slider'
                            r.SetProjExtState(0, 'FX Devices', 'Default Param type for FX:' .. FxGUID,
                                FX.Def_Type[FxGUID])
                        elseif r.ImGui_Selectable(ctx, 'Knob', false) then
                            FX.Def_Type[FxGUID] = 'Knob'
                            r.SetProjExtState(0, 'FX Devices', 'Default Param type for FX:' .. FxGUID,
                                FX.Def_Type[FxGUID])
                        elseif r.ImGui_Selectable(ctx, 'Drag', false) then
                            FX.Def_Type[FxGUID] = 'Drag'
                            r.SetProjExtState(0, 'FX Devices', 'Default Param type for FX:' .. FxGUID,
                                FX.Def_Type[FxGUID])
                        end
                        r.ImGui_EndCombo(ctx)
                    end
                    r.ImGui_EndPopup(ctx)
                end

                if OpenMorphSettings then
                    Open, Oms = r.ImGui_Begin(ctx, 'Preset Morph Settings ', Oms,
                        r.ImGui_WindowFlags_NoCollapse() + r.ImGui_WindowFlags_NoDocking())
                    if Oms then
                        if FxGUID == OpenMorphSettings then
                            r.ImGui_Text(ctx, 'Set blacklist parameters here: ')
                            local SpaceForBtn
                            Filter = r.ImGui_CreateTextFilter(FilterTxt)
                            r.ImGui_Text(ctx, 'Filter :')
                            r.ImGui_SameLine(ctx)
                            if FilterTxt then SpaceForBtn = 170 end
                            if r.ImGui_TextFilter_Draw(Filter, ctx, '##', -1 - (SpaceForBtn or 0)) then
                                FilterTxt = r.ImGui_TextFilter_Get(Filter)
                                r.ImGui_TextFilter_Set(Filter, Txt)
                            end
                            if FilterTxt then
                                SL()
                                BL_All = r.ImGui_Button(ctx, 'Blacklist all results')
                            end

                            r.ImGui_Text(ctx, 'Save morphing settings to : ')
                            SL()
                            local Save_FX = r.ImGui_Button(ctx, 'FX Instance', 80)
                            SL()
                            local Save_Proj = r.ImGui_Button(ctx, 'Project', 80)
                            SL()
                            local Save_Glob = r.ImGui_Button(ctx, 'Global', 80)
                            SL()
                            local FxNam = FX.Win_Name_S[FX_Idx]:gsub("%b()", "")
                            demo.HelpMarker(
                                'FX Instance: \nBlacklist will only apply to the current instance of ' ..
                                FxNam ..
                                '\n\nProject:\nBlacklist will apply to all instances of ' ..
                                FxNam ..
                                'in the current project\n\nGlobal:\nBlacklist will be applied to all instances of ' ..
                                FxNam ..
                                'across all projects.\n\nOrder of precedence goes from: FX Instance -> Project -> Global')



                            if Save_FX or Save_Proj or Save_Glob then
                                Tooltip_Timer = r.time_precise()
                                TTP_x, TTP_y = r.ImGui_GetMousePos(ctx)
                                r.ImGui_OpenPopup(ctx, '## Successfully saved preset morph')
                            end

                            if Tooltip_Timer then
                                if r.ImGui_BeginPopupModal(ctx, '## Successfully saved preset morph', nil, r.ImGui_WindowFlags_NoTitleBar()|r.ImGui_WindowFlags_NoResize()) then
                                    r.ImGui_Text(ctx, 'Successfully saved ')
                                    if r.ImGui_IsMouseClicked(ctx, 0) then
                                        r.ImGui_CloseCurrentPopup(
                                            ctx)
                                    end
                                    r.ImGui_EndPopup(ctx)
                                end

                                if Tooltip_Timer + 3 < r.time_precise() then
                                    Tooltip_Timer = nil
                                    TTP_x = nil
                                    TTP_y = nil
                                end
                            end

                            --


                            if not FX[FxGUID].PrmList[1].Name then
                                FX[FxGUID].PrmList = FX[FxGUID].PrmList or {}
                                --[[ local Ct = r.TrackFX_GetNumParams(LT_Track, FX_Idx)
                                for i=0, Ct-4, 1 do
                                    FX[FxGUID].PrmList[i]=FX[FxGUID].PrmList[i] or {}
                                    local rv, name = r.TrackFX_GetParamName(LT_Track, FX_Idx, i)
                                    FX[FxGUID].PrmList[i].Name  = name
                                end ]]

                                RestoreBlacklistSettings(FxGUID, FX_Idx, LT_Track,
                                    r.TrackFX_GetNumParams(LT_Track, FX_Idx), FX_Name)
                            else
                                r.ImGui_BeginTable(ctx, 'Parameter List', 5,
                                    r.ImGui_TableFlags_Resizable())
                                --r.ImGui_TableSetupColumn( ctx, 'BL',  flagsIn, 20,  user_idIn)

                                r.ImGui_TableHeadersRow(ctx)
                                r.ImGui_SetNextItemWidth(ctx, 20)
                                r.ImGui_TableSetColumnIndex(ctx, 0)

                                IconBtn(20, 20, 'M', 0x00000000)

                                r.ImGui_TableSetColumnIndex(ctx, 1)
                                r.ImGui_AlignTextToFramePadding(ctx)
                                r.ImGui_Text(ctx, 'Parameter Name ')
                                r.ImGui_TableSetColumnIndex(ctx, 2)
                                r.ImGui_AlignTextToFramePadding(ctx)
                                r.ImGui_Text(ctx, 'A')
                                r.ImGui_TableSetColumnIndex(ctx, 3)
                                r.ImGui_AlignTextToFramePadding(ctx)
                                r.ImGui_Text(ctx, 'B')
                                r.ImGui_TableNextRow(ctx)
                                r.ImGui_TableSetColumnIndex(ctx, 0)




                                if --[[Last Touch]] LT_ParamNum and LT_FXGUID == FxGUID then
                                    local P = FX[FxGUID].PrmList
                                    local N = math.max(LT_ParamNum, 1)
                                    r.ImGui_TableSetBgColor(ctx, 1,
                                        getClr(r.ImGui_Col_TabUnfocused()))
                                    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, 9)

                                    rv, P[N].BL = r.ImGui_Checkbox(ctx, '##' .. N, P[N].BL)
                                    if P[N].BL then r.ImGui_BeginDisabled(ctx) end

                                    r.ImGui_TableSetColumnIndex(ctx, 1)
                                    r.ImGui_Text(ctx, N .. '. ' .. (P[N].Name or ''))


                                    ------- A --------------------
                                    r.ImGui_TableSetColumnIndex(ctx, 2)
                                    r.ImGui_Text(ctx, 'A:')
                                    SL()
                                    r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)

                                    local i = LT_ParamNum or 0
                                    local OrigV = r.TrackFX_GetParamNormalized(LT_Track,
                                        FX_Idx, i)
                                    if not P.FormatV_A and FX[FxGUID].MorphA[1] then
                                        P.FormatV_A =
                                            GetFormatPrmV(FX[FxGUID].MorphA[i], OrigV, i)
                                    end


                                    P.Drag_A, FX[FxGUID].MorphA[i] = r.ImGui_DragDouble(ctx,
                                        '## MorphVal_A' .. i, FX[FxGUID].MorphA[i], 0.01, 0, 1,
                                        P.FormatV_A or '')
                                    if P.Drag_A then
                                        P.FormatV_A = GetFormatPrmV(FX[FxGUID].MorphA[i], OrigV, i)
                                    end

                                    SL()
                                    --------- B --------------------
                                    r.ImGui_TableSetColumnIndex(ctx, 3)
                                    r.ImGui_Text(ctx, 'B:')
                                    SL()

                                    local OrigV = r.TrackFX_GetParamNormalized(LT_Track,
                                        FX_Idx, i)
                                    r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                                    if not P.FormatV_B and FX[FxGUID].MorphB[1] then
                                        P.FormatV_B = GetFormatPrmV(FX[FxGUID].MorphB[i], OrigV, i)
                                    end


                                    P.Drag_B, FX[FxGUID].MorphB[i] = r.ImGui_DragDouble(ctx,
                                        '## MorphVal_B' .. i, FX[FxGUID].MorphB[i], 0.01, 0, 1,
                                        P.FormatV_B)
                                    if P.Drag_B then
                                        P.FormatV_B = GetFormatPrmV(FX[FxGUID].MorphB[i], OrigV, i)
                                    end


                                    if P[N].BL then r.ImGui_EndDisabled(ctx) end
                                    --HighlightSelectedItem( 0xffffff33 , OutlineClr, 1, L,T,R,B,h,w, H_OutlineSc, V_OutlineSc,'GetItemRect', Foreground)

                                    r.ImGui_PopStyleVar(ctx)
                                    r.ImGui_TableNextRow(ctx)
                                    r.ImGui_TableSetColumnIndex(ctx, 0)
                                end
                                local Load_FX_Proj_Glob
                                local _, FXsBL = r.GetSetMediaTrackInfo_String(LT_Track,
                                    'P_EXT: Morph_BL' .. FxGUID, '', false)
                                if FXsBL == 'Has Blacklist saved to FX' then -- if there's FX-specific BL settings
                                    Load_FX_Proj_Glob = 'FX'
                                else
                                    local _, whether = r.GetProjExtState(0,
                                        'FX Devices - Preset Morph',
                                        'Whether FX has Blacklist' .. (FX.Win_Name_S[FX_Idx] or ''))
                                    if whether == 'Yes' then Load_FX_Proj_Glob = 'Proj' end
                                end

                                local TheresBL = TheresBL or {}
                                local hasBL
                                for i, v in ipairs(FX[FxGUID].PrmList) do
                                    local P = FX[FxGUID].PrmList[i - 1]
                                    local prm = FX[FxGUID].PrmList

                                    if r.ImGui_TextFilter_PassFilter(Filter, P.Name) --[[ and (i~=LT_ParamNum and LT_FXGUID==FxGUID) ]] then
                                        i = i - 1
                                        if prm[i].BL == nil then
                                            if Load_FX_Proj_Glob == 'FX' then
                                                local _, V = r.GetSetMediaTrackInfo_String(
                                                    LT_Track,
                                                    'P_EXT: Morph_BL' .. FxGUID .. i, '', false)
                                                if V == 'Blacklisted' then prm[i].BL = true end
                                            end
                                            --[[  elseif Load_FX_Proj_Glob== 'Proj' then
                                                local rv, BLprm  = r.GetProjExtState(0,'FX Devices - Preset Morph', FX.Win_Name_S[FX_Idx]..' Blacklist '..i)
                                                if BLprm~='' and BLprm then  BLpm = tonumber(BLprm)
                                                    if BLprm then prm[1].BL = true  end
                                                end
                                            end ]]
                                        end
                                        if BL_All --[[BL all filtered params ]] then if P.BL then P.BL = false else P.BL = true end end
                                        rv, prm[i].BL = r.ImGui_Checkbox(ctx, '## BlackList' .. i,
                                            prm[i].BL)

                                        r.ImGui_TableSetColumnIndex(ctx, 1)
                                        if P.BL then
                                            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),
                                                getClr(r.ImGui_Col_TextDisabled()))
                                        end


                                        r.ImGui_Text(ctx, i .. '. ' .. (P.Name or ''))



                                        ------- A --------------------
                                        r.ImGui_TableSetColumnIndex(ctx, 2)
                                        r.ImGui_Text(ctx, 'A:')
                                        SL()

                                        local OrigV = r.TrackFX_GetParamNormalized(LT_Track,
                                            FX_Idx,
                                            i)
                                        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                                        if not P.FormatV_A and FX[FxGUID].MorphA[1] then
                                            P.FormatV_A =
                                                GetFormatPrmV(FX[FxGUID].MorphA[i + 1], OrigV, i)
                                        end


                                        P.Drag_A, FX[FxGUID].MorphA[i] = r.ImGui_DragDouble(ctx,
                                            '## MorphVal_A' .. i, FX[FxGUID].MorphA[i], 0.01, 0, 1,
                                            P.FormatV_A or '')
                                        if P.Drag_A then
                                            P.FormatV_A = GetFormatPrmV(FX[FxGUID].MorphA[i], OrigV,
                                                i)
                                            --[[ r.TrackFX_SetParamNormalized(LT_Track, FX_Idx,i, FX[FxGUID].MorphA[i])
                                            _,P.FormatV_A = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx,i)
                                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx,i, OrigV)  ]]
                                        end

                                        SL()

                                        --------- B --------------------
                                        r.ImGui_TableSetColumnIndex(ctx, 3)
                                        r.ImGui_Text(ctx, 'B:')
                                        SL()

                                        local OrigV = r.TrackFX_GetParamNormalized(LT_Track,
                                            FX_Idx,
                                            i)
                                        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                                        if not P.FormatV_B and FX[FxGUID].MorphB[1] then
                                            P.FormatV_B = GetFormatPrmV(FX[FxGUID].MorphB[i] or 0,
                                                OrigV, i)
                                        end

                                        P.Drag_B, FX[FxGUID].MorphB[i] = r.ImGui_DragDouble(ctx,
                                            '## MorphVal_B' .. i, FX[FxGUID].MorphB[i], 0.01, 0, 1,
                                            P.FormatV_B)
                                        if P.Drag_B then
                                            P.FormatV_B = GetFormatPrmV(FX[FxGUID].MorphB[i], OrigV,
                                                i)
                                        end


                                        if Save_FX then
                                            if P.BL then
                                                hasBL = true
                                                r.GetSetMediaTrackInfo_String(LT_Track,
                                                    'P_EXT: Morph_BL' .. FxGUID .. i, 'Blacklisted',
                                                    true)
                                            else
                                                r.GetSetMediaTrackInfo_String(LT_Track,
                                                    'P_EXT: Morph_BL' .. FxGUID .. i, '', true)
                                            end
                                            if hasBL then
                                                r.GetSetMediaTrackInfo_String(LT_Track,
                                                    'P_EXT: Morph_BL' .. FxGUID,
                                                    'Has Blacklist saved to FX', true)
                                            else
                                                r.GetSetMediaTrackInfo_String(LT_Track,
                                                    'P_EXT: Morph_BL' .. FxGUID, '', true)
                                            end
                                        elseif Save_Proj then
                                            if P.BL then table.insert(TheresBL, i) end
                                        elseif Save_Glob then
                                            if P.BL then table.insert(TheresBL, i) end
                                        end

                                        r.ImGui_SetNextItemWidth(ctx, -1)

                                        if P.BL then r.ImGui_PopStyleColor(ctx) end

                                        r.ImGui_TableNextRow(ctx)
                                        r.ImGui_TableSetColumnIndex(ctx, 0)
                                    end
                                end

                                if Save_Proj then
                                    if TheresBL[1] then
                                        r.SetProjExtState(0, 'FX Devices - Preset Morph',
                                            'Whether FX has Blacklist' .. FX.Win_Name_S[FX_Idx],
                                            'Yes')
                                    else
                                        r.SetProjExtState(0, 'FX Devices - Preset Morph',
                                            'Whether FX has Blacklist' .. FX.Win_Name_S[FX_Idx], 'No')
                                    end
                                    for i, V in ipairs(FX[FxGUID].MorphA) do
                                        local PrmBLed
                                        for I, v in ipairs(TheresBL) do
                                            if i == v then PrmBLed = v end
                                        end
                                        if PrmBLed then
                                            r.SetProjExtState(0, 'FX Devices - Preset Morph',
                                                FX.Win_Name_S[FX_Idx] .. ' Blacklist ' .. i, PrmBLed)
                                        else
                                            r.SetProjExtState(0, 'FX Devices - Preset Morph',
                                                FX.Win_Name_S[FX_Idx] .. ' Blacklist ' .. i, '')
                                        end
                                    end
                                    --else r.SetProjExtState(0,'FX Devices - Preset Morph','Whether FX has Blacklist'..FX.Win_Name_S[FX_Idx], '')
                                elseif TheresBL[1] and Save_Glob then
                                    file, file_path = CallFile('w', FX.Win_Name_S[FX_Idx] .. '.ini',
                                        'Preset Morphing')
                                    if file then
                                        for i, V in ipairs(TheresBL) do
                                            file:write(i, ' = ', V, '\n')
                                        end
                                        file:close()
                                    end
                                end

                                r.ImGui_EndTable(ctx)
                            end
                        end
                        r.ImGui_End(ctx)
                    else
                        r.ImGui_End(ctx)
                        OpenMorphSettings = false
                    end
                end

                ------------------------------------------
                ------ Collapse Window
                ------------------------------------------

                local FX_Idx = FX_Idx or 1



                r.gmem_attach('ParamValues')
                FX.Win_Name_S[FX_Idx] = ChangeFX_Name(FX.Win_Name[FX_Idx] or FX_Name)

                FX_Name = string.sub(FX_Name, 1, (string.find(FX_Name, '%(') or 30) - 1)
                FX_Name = string.gsub(FX_Name, '%-', ' ')






                r.ImGui_SameLine(ctx)

                --------------------------------
                ----Area right of window title
                --------------------------------
                function SyncWetValues(id)
                    local id = FX_Idx or id 
                    --when track change
                    if Wet.Val[id] == nil or TrkID ~= TrkID_End or FXCountEndLoop ~= Sel_Track_FX_Count then -- if it's nil
                        Glob.SyncWetValues = true
                    end

                    if Glob.SyncWetValues == true then
                        Wet.P_Num[id] = r.TrackFX_GetParamFromIdent(LT_Track, id,':wet')
                        Wet.Get = r.TrackFX_GetParamNormalized(LT_Track, id,
                            Wet.P_Num[id])
                        Wet.Val[id] = Wet.Get
                    end
                    if Glob.SyncWetValues == true and id == Sel_Track_FX_Count - 1 then
                        Glob.SyncWetValues = false
                    end
                    if LT_ParamNum == Wet.P_Num[id] and focusedFXState == 1 then
                        Wet.Get = r.TrackFX_GetParamNormalized(LT_Track, id,
                            Wet.P_Num[id])
                        Wet.Val[id] = Wet.Get
                    elseif LT_ParamNum == FX[FxGUID].DeltaP then
                        FX[FxGUID].DeltaP_V = r.TrackFX_GetParamNormalized(LT_Track, id,
                            FX[FxGUID].DeltaP)
                    end
                end


                if FindStringInTable(SpecialLayoutFXs, FX_Name) == false and not FindStringInTable(PluginScripts, FX.Win_Name_S[FX_Idx]) then
                    SyncWetValues()

                    if FX[FxGUID].Collapse ~= true then
                        Wet.ActiveAny, Wet.Active, Wet.Val[FX_Idx] = Add_WetDryKnob(ctx, 'a', '', Wet.Val[FX_Idx] or 1, 0, 1, FX_Idx)
                    end

                    if r.ImGui_BeginDragDropTarget(ctx) then
                        rv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX_Drag')
                        if rv then
                        end
                        r.ImGui_EndDragDropTarget(ctx)
                    end
                end
                -- r.ImGui_PopStyleVar(ctx) --StyleVar#4  POP (Things in the header of FX window)

                ------------------------------------------
                ------ Generic FX's knobs and sliders area
                ------------------------------------------


                local function Decide_If_Create_Regular_Layout()
                    if not FX[FxGUID].Collapse and FindStringInTable(BlackListFXs, FX_Name) ~= true and FindStringInTable(SpecialLayoutFXs, FX_Name) == false  then
                        local FX_has_Plugin
                        for i, v in pairs(PluginScripts) do
                            if FX_Name:find(v) then
                                FX_has_Plugin = true  
                            end
                        end

                        if not FX_has_Plugin then  return true  
                        else
                            if FX[FxGUID].Compatible_W_regular then  return true  end 
                        end
                    end
                end

                if Decide_If_Create_Regular_Layout() then 
                    local WinP_X; local WinP_Y;
                    --_, foo = AddKnob(ctx, 'test', foo or 0  , 0, 100 )
                    if FX.Enable[FX_Idx] == true then
                        -- Params Colors-----
                        --[[ r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x32403aff)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(), 0x44444488)

                        times = 2 ]]
                    else
                        --[[ r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x17171744)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x66666644)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrab(), 0x66666644)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(), 0x66666622)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(), 0x44444422)
                        times = 5 ]]
                    end

                    if FX[FxGUID].Round then
                        r.ImGui_PushStyleVar(ctx,
                            r.ImGui_StyleVar_FrameRounding(), FX[FxGUID].Round)
                    end
                    if FX[FxGUID].GrbRound then
                        r.ImGui_PushStyleVar(ctx,
                            r.ImGui_StyleVar_GrabRounding(), FX[FxGUID].GrbRound)
                    end

                    if (FX.LayEdit == FxGUID or Draw.DrawMode[FxGUID] == true) and Mods ~= Apl then
                        r.ImGui_BeginDisabled(ctx, true)
                    end
                    if FX.LayEdit then
                        LE.DragX, LE.DragY = r.ImGui_GetMouseDragDelta(ctx, 0)
                    end

                    ------------------------------------------------------
                    -- Repeat as many times as stored Param on FX -------------
                    ------------------------------------------------------
                    --[[ for Fx_P, v in ipairs(FX[FxGUID])    do
                        if not FX[FxGUID][Fx_P].Name then table.remove(FX[FxGUID],Fx_P) end
                    end ]]
                    for Fx_P, v in ipairs(FX[FxGUID]) do --parameter faders
                        --FX[FxGUID][Fx_P]= FX[FxGUID][Fx_P] or {}



                        local FP = FX[FxGUID][Fx_P] ---@class FX_P

                        local F_Tp = FX.Prm.ToTrkPrm[FxGUID .. Fx_P]; 
                        local ID = FxGUID ..Fx_P
                        Rounding = 0.5

                        ParamX_Value = 'Param' ..
                            tostring(FP.Name) .. 'On  ID:' .. tostring(Fx_P) .. 'value' .. FxGUID

                        ----Default Layouts
                        if not FP.PosX and not FP.PosY then
                            if FP.Type == 'Slider' or (not FP.Type and not FX.Def_Type[FxGUID]) or FX.Def_Type[FxGUID] == 'Slider' or FP.Type == 'Drag' or (FX.Def_Type[FxGUID] == 'Drag' and FP.Type == nil) then
                                local Column = math.floor((Fx_P / 6) - 0.01)
                                local W = ((FX[FxGUID][Fx_P - Column * 6].Sldr_W or FX.Def_Sldr_W[FxGUID] or 160) + GapBtwnPrmColumns) *
                                    Column
                                local Y = 30 * (Fx_P - (Column * 6))
                                r.ImGui_SetCursorPos(ctx, W, Y)
                            elseif FP.Type == 'V-Slider' or (FX.Def_Type[FxGUID] == 'V-Slider' and FP.Type == nil) then
                                r.ImGui_SetCursorPos(ctx, 17 * (Fx_P - 1), 30)
                            elseif FP.Type == 'Knob' or (FX.Def_Type[FxGUID] == 'Knob' and FP.Type == nil) then
                                local KSz = Df.KnobSize
                                local G = 15
                                local Column = math.floor(Fx_P / 3 - 0.1)

                                r.ImGui_SetCursorPos(ctx, KSz * (Column),
                                    26 + (KSz + G) * (Fx_P - (Column * 3) - 1))
                            end
                        end

                        if FP.PosX then r.ImGui_SetCursorPosX(ctx, FP.PosX) end
                        if FP.PosY then r.ImGui_SetCursorPosY(ctx, FP.PosY) end

                        rectminX, RectMinY = r.ImGui_GetItemRectMin(ctx)
                        curX, CurY = r.ImGui_GetCursorPos(ctx)
                        if CurY > 210 then
                            r.ImGui_SetCursorPosY(ctx, 210)
                            CurY = 210
                        end
                        if curX < 0 then
                            r.ImGui_SetCursorPosX(ctx, 0)
                        elseif curX > (FX[FxGUID].Width or DefaultWidth) then
                            r.ImGui_SetCursorPosX(ctx, (FX[FxGUID].Width or DefaultWidth) - 10)
                        end

                        -- if prm has clr set, calculate colors for active and hvr clrs
                        if FP.BgClr then
                            local R, G, B, A = r.ImGui_ColorConvertU32ToDouble4(FP.BgClr)
                            local H, S, V = r.ImGui_ColorConvertRGBtoHSV(R, G, B)
                            local HvrV, ActV
                            if V > 0.9 then
                                HvrV = V - 0.1
                                ActV = V - 0.5
                            end
                            local R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, HvrV or V +
                                0.1)
                            local HvrClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
                            local R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, ActV or V + 0.2)
                            local ActClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
                            FP.BgClrHvr = HvrClr
                            FP.BgClrAct = ActClr
                        end


                        --- if there's condition for parameters --------
                        local CreateParam, ConditionPrms, Pass = nil, {}, {}

                        ---@param ConditionPrm "ConditionPrm"
                        ---@param ConditionPrm_PID "ConditionPrm_PID"
                        ---@param ConditionPrm_V_Norm "ConditionPrm_V_Norm"
                        ---@param ConditionPrm_V "ConditionPrm_V"
                        ---@return boolean
                        local function CheckIfCreate(ConditionPrm, ConditionPrm_PID,
                                                     ConditionPrm_V_Norm, ConditionPrm_V)
                            local Pass -- TODO should this be initialized to false?
                            if FP[ConditionPrm] then
                                if not FX[FxGUID][Fx_P][ConditionPrm_PID] then
                                    for i, v in ipairs(FX[FxGUID]) do
                                        if v.Num == FX[FxGUID][Fx_P][ConditionPrm] then
                                            FX[FxGUID][Fx_P][ConditionPrm_PID] =
                                                i
                                        end
                                    end
                                end
                                local PID = FP[ConditionPrm_PID]

                                if FX[FxGUID][PID].ManualValues then
                                    local V = round(
                                        r.TrackFX_GetParamNormalized(LT_Track, FX_Idx,
                                            FP[ConditionPrm]),
                                        3)
                                    if FP[ConditionPrm_V_Norm] then
                                        for i, v in ipairs(FP[ConditionPrm_V_Norm]) do
                                            if V == round(v, 3) then Pass = true end
                                        end
                                    end
                                else
                                    local _, V = r.TrackFX_GetFormattedParamValue(LT_Track,
                                        FX_Idx,
                                        FP[ConditionPrm])
                                    for i, v in ipairs(FP[ConditionPrm_V]) do
                                        if V == v then Pass = true end
                                    end
                                end
                            else
                                Pass = true
                            end
                            return Pass
                        end

                        if FP['ConditionPrm'] then
                            if CheckIfCreate('ConditionPrm', 'ConditionPrm_PID', 'ConditionPrm_V_Norm', 'ConditionPrm_V') then
                                local DontCretePrm
                                for i = 2, 5, 1 do
                                    if CheckIfCreate('ConditionPrm' .. i, 'ConditionPrm_PID' .. i, 'ConditionPrm_V_Norm' .. i, 'ConditionPrm_V' .. i) then
                                    else
                                        DontCretePrm = true
                                    end
                                end
                                if not DontCretePrm then CreateParam = true end
                            end
                        end




                        if CreateParam or not FP.ConditionPrm then
                            local Prm = FP
                            local F_Tp = FX.Prm.ToTrkPrm[FxGUID .. Fx_P]




                            if Prm and FxGUID then

                                DL_SPLITER = r.ImGui_CreateDrawListSplitter(WDL)
                                r.ImGui_DrawListSplitter_Split(DL_SPLITER, 2)
                                r.ImGui_DrawListSplitter_SetCurrentChannel(DL_SPLITER, 1)
                                --Prm.V = Prm.V or r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, Prm.Num)
                                --- Add Parameter controls ---------
                                if Prm.Type == 'Slider' or (not Prm.Type and not FX.Def_Type[FxGUID]) or FX.Def_Type[FxGUID] == 'Slider' then
                                    AddSlider(ctx, '##' .. (Prm.Name or Fx_P)..FX_Name, Prm.CustomLbl,
                                        Prm.V or 0, 0, 1, Fx_P, FX_Idx, Prm.Num, Style,
                                        Prm.Sldr_W or FX.Def_Sldr_W[FxGUID], 0, Disable, Vertical,
                                        GrabSize, Prm.Lbl, 8)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'Sldr', curX, CurY)
                                elseif FP.Type == 'Knob' or (FX.Def_Type[FxGUID] == 'Knob' and Prm.Type == nil) then
                                    AddKnob(ctx, '##' .. Prm.Name..FX_Name, Prm.CustomLbl, Prm.V, 0, 1, Fx_P,
                                        FX_Idx, Prm.Num, Prm.Style, Prm.Sldr_W or Df.KnobRadius, 0,
                                        Disabled, Prm.FontSize, Prm.Lbl_Pos or 'Bottom', Prm.V_Pos)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'Knob', curX, CurY)
                                elseif Prm.Type == 'V-Slider' or (FX.Def_Type[FxGUID] == 'V-Slider') then
                                    AddSlider(ctx, '##' .. Prm.Name..FX_Name, Prm.CustomLbl, Prm.V or 0, 0, 1,
                                        Fx_P, FX_Idx, Prm.Num, Style, Prm.Sldr_W or 15, 0, Disable,
                                        'Vert', GrabSize, Prm.Lbl, nil, Prm.Sldr_H or 160)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'V-Slider', curX, CurY)
                                elseif Prm.Type == 'Switch' then
                                    AddSwitch(LT_Track, FX_Idx, Prm.V or 0, Prm.Num, Prm.BgClr, Prm.CustomLbl or 'Use Prm Name as Lbl', Fx_P, F_Tp,
                                        Prm.FontSize, FxGUID)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'Switch', curX, CurY)
                                elseif Prm.Type == 'Drag' or (FX.Def_Type[FxGUID] == 'Drag') then
                                    AddDrag(ctx, '##' .. Prm.Name..FX_Name, Prm.CustomLbl or Prm.Name,
                                        Prm.V or 0, 0, 1, Fx_P, FX_Idx, Prm.Num, Prm.Style,
                                        Prm.Sldr_W or FX.Def_Sldr_W[FxGUID] or Df.Sldr_W, -1, Disable,
                                        Lbl_Clickable, Prm.Lbl_Pos, Prm.V_Pos, Prm.DragDir)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'Drag', curX, CurY)
                                elseif Prm.Type == 'Selection' then
                                    AddCombo(ctx, LT_Track, FX_Idx,
                                        Prm.Name .. FxGUID .. '## actual',Prm.Num, FP.ManualValuesFormat or 'Get Options', Prm.Sldr_W, Prm.Style, FxGUID, Fx_P, FP.ManualValues)
                                    MakeItemEditable(FxGUID, Fx_P, Prm.Sldr_W, 'Selection', curX,
                                        CurY)
                                end

                                if r.ImGui_IsItemClicked(ctx) and LBtnDC then
                                    if Mods == 0 then
                                        local dir_path = CurrentDirectory .. 'src'
                                        local file_path = ConcatPath(dir_path,
                                            'FX Default Values.ini')
                                        local file = io.open(file_path, 'r')

                                        if file then
                                            local FX_Name = ChangeFX_Name(FX_Name)
                                            Content = file:read('*a')
                                            local Ct = Content
                                            local P_Num = Prm.Num
                                            local _, P_Nm = r.TrackFX_GetParamName(LT_Track,
                                                FX_Idx,
                                                P_Num)
                                            local Df = RecallGlobInfo(Ct,
                                                P_Num .. '. ' .. P_Nm .. ' = ', 'Num')
                                            if Df then
                                                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx,
                                                    P_Num,
                                                    Df)
                                                ToDef = { ID = FX_Idx, P = P_Num, V = Df }
                                            end
                                        end
                                    elseif Mods == Alt then
                                        if Prm.Deletable then
                                            DeletePrm(FxGUID, Fx_P, FX_Idx)
                                        end
                                    end
                                end
    
                                if ToDef.ID and ToDef.V then
                                    r.TrackFX_SetParamNormalized(LT_Track, ToDef.ID, ToDef.P,
                                        ToDef
                                        .V)
                                    if Prm.WhichCC then
                                        if Trk.Prm.WhichMcros[Prm.WhichCC .. TrkID] then
                                            local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.active", 0)   -- 1 active, 0 inactive
                                            r.TrackFX_SetParamNormalized(LT_Track, ToDef.ID,
                                                ToDef.P,
                                                ToDef.V)
                                            r.GetSetMediaTrackInfo_String(LT_Track,
                                                'P_EXT: FX' ..
                                                FxGUID ..
                                                'Prm' .. ToDef.P .. 'Value before modulation',
                                                ToDef.V, true)
                                            r.gmem_write(7, Prm.WhichCC) --tells jsfx to retrieve P value
                                            PM.TimeNow = r.time_precise()
                                            r.gmem_write(11000 + Prm.WhichCC, ToDef.V)
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.active", 1)   -- 1 active, 0 inactive
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.effect", -100) -- -100 enables midi_msg*
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.param", -1)   -- -1 not parameter link
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.midi_msg", 176)   -- 176 is CC
                                            r.TrackFX_SetNamedConfigParm(LT_Track, ToDef.ID, "param."..ToDef.P..".plink.midi_msg2", Prm.WhichCC) -- CC value                                                                
                                        end
                                    end
                                    Prm.V = ToDef.V

                                    ToDef = {}
                                end


                                if FP.Draw then
                                    r.ImGui_DrawListSplitter_SetCurrentChannel(DL_SPLITER, 0)

                                    local function Repeat(rpt, va, Xgap, Ygap, func, Gap, RPTClr, CLR)
                                        if rpt and rpt ~= 0 then
                                            local RPT = rpt
                                            if va and va ~= 0 then RPT = rpt * Prm.V * va end
                                            for i = 0, RPT - 1, 1 do
                                                local Clr = BlendColors(CLR or 0xffffffff,
                                                    RPTClr or 0xffffffff, i / RPT)

                                                func(i * (Xgap or 0), i * (Ygap or 0), i * (Gap or 0),
                                                    Clr)
                                            end
                                        else
                                            func(Xgap)
                                        end
                                    end




                                    local GR = tonumber(select(2, r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, 'GainReduction_dB')))

                                    for i, v in ipairs(FP.Draw) do
                                        local x, y              = r.ImGui_GetItemRectMin(ctx)
                                        Prm.V = Prm.V or 0
                                        local x                 = x + (v.X_Offset or 0) + (Prm.V * (v.X_Offset_VA or 0)) + ((GR or 0) * (v.X_Offset_VA_GR or 0))
                                        local y                 = y + (v.Y_Offset or 0) + (Prm.V * (v.Y_Offset_VA or 0)) + ((GR or 0) * (v.Y_Offset_VA_GR or 0))
                                        local Thick             = (v.Thick or 2)
                                        local Gap, X_Gap, Y_Gap = v.Gap, v.X_Gap, v.Y_Gap
                                        local Clr_VA
                                        if v.Clr_VA then
                                            Clr_VA = BlendColors(v.Clr or 0xffffffff,
                                                v.Clr_VA, Prm.V)
                                        end



                                        if v.X_Gap_VA and v.X_Gap_VA ~= 0 then
                                            X_Gap = (v.X_Gap or 0) *Prm.V * v.X_Gap_VA
                                        end
                                        if v.Y_Gap_VA and v.Y_Gap_VA ~= 0 then
                                            Y_Gap = (v.Y_Gap or 0) * Prm.V * v.Y_Gap_VA
                                        end

                                        if v.Gap_VA and v.Gap_VA ~= 0 and v.Gap then
                                            Gap = v.Gap * Prm.V * v.Gap_VA
                                        end

                                        if v.Thick_VA then
                                            Thick = (v.Thick or 2) * (v.Thick_VA * Prm.V)
                                        end

                                        if v.Type == 'Line' or v.Type == 'Rect' or v.Type == 'Rect Filled' then
                                            local w = v.Width or r.ImGui_GetItemRectSize(ctx)
                                            local h = v.Height or select(2, r.ImGui_GetItemRectSize(ctx))

                                            local x2 = x + w
                                            local y2 = y + h
                                            local GR = GR or 0

                                            if v.Width_VA and v.Width_VA ~= 0 then
                                                x2 = x + (w or 10) * Prm.V * (v.Width_VA)
                                            end
                                            if v.Width_VA_GR then 
                                                x2 = x + (w or 10) * (GR * (v.Width_VA_GR or 0))
                                            end

                                            if v.Height_VA and v.Height_VA ~= 0 then
                                                y2 = y + (h or 10) * Prm.V * (v.Height_VA) 
                                            end
                                            if v.Height_VA_GR and v.Height_VA_GR ~=0 then 

                                                y2 = y + (h or 10) * GR * (v.Height_VA_GR) 

                                            end



                                            if v.Type == 'Line' then
                                                if Prm.Type == 'Slider' or Prm.Type == 'Drag' or (not Prm.Type) then
                                                    v.Height = v.Height or 0; v.Width = v.Width or w
                                                    h        = v.Height or 0; w = v.Width or w
                                                elseif Prm.Type == 'V-Slider' then
                                                    v.Height = v.Height or h; v.Width = v.Width or 0
                                                    h = v.Height or h; w = v.Width or 0
                                                end


                                                local function Addline(Xg, Yg, none, RptClr)
                                                    r.ImGui_DrawList_AddLine(WDL, x + (Xg or 0),
                                                        y + (Yg or 0), x2 + (Xg or 0), y2 + (Yg or 0),
                                                        RptClr or Clr_VA or v.Clr or 0xffffffff,
                                                        Thick)
                                                end

                                                Repeat(v.Repeat, v.Repeat_VA, X_Gap, Y_Gap, Addline,
                                                    nil, v.RPT_Clr, v.Clr)
                                            elseif v.Type == 'Rect' then
                                                local function AddRect(Xg, Yg, none, RptClr)
                                                    r.ImGui_DrawList_AddRect(WDL, x + (Xg or 0),
                                                        y + (Yg or 0), x2 + (Xg or 0), y2 + (Yg or 0),
                                                        RptClr or Clr_VA or v.Clr or 0xffffffff,
                                                        v.Round, flag, Thick)
                                                end
                                                Repeat(v.Repeat, v.Repeat_VA, X_Gap, Y_Gap, AddRect,
                                                    nil, v.RPT_Clr, v.Clr)
                                            elseif v.Type == 'Rect Filled' then
                                                local function AddRectFill(Xg, Yg, none, RptClr)
                                                    r.ImGui_DrawList_AddRectFilled(WDL, x + (Xg or 0),
                                                        y + (Yg or 0), x2 + (Xg or 0), y2 + (Yg or 0),
                                                        RptClr or Clr_VA or v.Clr or 0xffffffff,
                                                        v.Round)
                                                end
                                                Repeat(v.Repeat, v.Repeat_VA, X_Gap, Y_Gap,
                                                    AddRectFill, nil, v.RPT_Clr, v.Clr)
                                            end

                                            if v.AdjustingX or v.AdjustingY then
                                                local l = 4
                                                r.ImGui_DrawList_AddLine(WDL, x - l, y - l, x + l,
                                                    y + l, 0xffffffdd)
                                                r.ImGui_DrawList_AddLine(WDL, x - l, y + l, x + l,
                                                    y - l, 0xffffffdd)
                                            end
                                        elseif v.Type == 'Circle' or v.Type == 'Circle Filled' then
                                            local w, h = 10
                                            if Prm.Type == 'Knob' then
                                                w, h = r
                                                    .ImGui_GetItemRectSize(ctx)
                                            else
                                                v.Width = v.Width or
                                                    10
                                            end
                                            local Rad = v.Width or w
                                            if v.Width_VA and v.Width_VA ~= 0 then
                                                Rad = Rad * Prm.V *
                                                    v.Width_VA
                                            end

                                            local function AddCircle(X_Gap, Y_Gap, Gap, RptClr)
                                                r.ImGui_DrawList_AddCircle(WDL,
                                                    x + w / 2 + (X_Gap or 0),
                                                    y + w / 2 + (Y_Gap or 0), Rad + (Gap or 0),
                                                    RptClr or Clr_VA or v.Clr or 0xffffffff, nil,
                                                    Thick)
                                            end
                                            local function AddCircleFill(X_Gap, Y_Gap, Gap, RptClr)
                                                r.ImGui_DrawList_AddCircleFilled(WDL,
                                                    x + w / 2 + (X_Gap or 0),
                                                    y + w / 2 + (Y_Gap or 0), Rad + (Gap or 0),
                                                    RptClr or Clr_VA or v.Clr or 0xffffffff)
                                            end


                                            if v.Type == 'Circle' then
                                                Repeat(v.Repeat, v.Repeat_VA, X_Gap, Y_Gap, AddCircle,
                                                    Gap, v.RPT_Clr, v.Clr)
                                            elseif v.Type == 'Circle Filled' then
                                                Repeat(v.Repeat, v.Repeat_VA, X_Gap, Y_Gap,
                                                    AddCircleFill, Gap, v.RPT_Clr, v.Clr)
                                            end

                                            if v.AdjustingX or v.AdjustingY then
                                                local l = 4
                                                local x, y = x + Rad / 2, y + Rad / 2
                                                r.ImGui_DrawList_AddLine(WDL, x - l, y - l, x + l,
                                                    y + l, 0xffffffdd)
                                                r.ImGui_DrawList_AddLine(WDL, x - l, y + l, x + l,
                                                    y - l, 0xffffffdd)
                                            end
                                        elseif v.Type == 'Knob Pointer' or v.Type == 'Knob Range' or v.Type == 'Knob Image' or v.Type == 'Knob Circle' then
                                            local w, h = r.ImGui_GetItemRectSize(ctx)
                                            local x, y = x + w / 2 + (v.X_Offset or 0),
                                                y + h / 2 + (v.Y_Offset or 0)
                                            local ANGLE_MIN = 3.141592 * (v.Angle_Min or 0.75)
                                            local ANGLE_MAX = 3.141592 * (v.Angle_Max or 2.25)
                                            local t = (Prm.V - 0) / (1 - 0)
                                            local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
                                            local angle_cos, angle_sin = math.cos(angle),
                                                math.sin(angle)
                                            local IN = v.Rad_In or
                                                0 -- modify this for the center begin point
                                            local OUT = v.Rad_Out or 30

                                            if v.Type == 'Knob Pointer' then
                                                r.ImGui_DrawList_AddLine(WDL, x + angle_cos * IN,
                                                    y + angle_sin * IN, x + angle_cos * (OUT - Thick),
                                                    y + angle_sin * (OUT - Thick),
                                                    Clr_VA or v.Clr or 0x999999aa, Thick)
                                            elseif v.Type == 'Knob Range' then
                                                local function AddRange(G)
                                                    for i = IN, OUT, (1 + (v.Gap or 0)) do
                                                        r.ImGui_DrawList_PathArcTo(WDL, x, y, i,
                                                            ANGLE_MIN,
                                                            SetMinMax(
                                                                ANGLE_MIN +
                                                                (ANGLE_MAX - ANGLE_MIN) * Prm.V,
                                                                ANGLE_MIN, ANGLE_MAX))
                                                        r.ImGui_DrawList_PathStroke(WDL,
                                                            Clr_VA or v.Clr or 0x999999aa, nil, Thick)
                                                        r.ImGui_DrawList_PathClear(WDL)
                                                    end
                                                end


                                                Repeat(1, 0, X_Gap, X_Gap, AddRange)
                                            elseif v.Type == 'Knob Circle' then
                                                r.ImGui_DrawList_AddCircle(WDL, x + angle_cos * IN,
                                                    y + angle_sin * IN, v.Width,
                                                    Clr_VA or v.Clr or 0x999999aa, nil, Thick)
                                            elseif v.Type == 'Knob Image' and v.Image then
                                                local X, Y = x + angle_cos * IN, y + angle_sin * IN
                                                r.ImGui_DrawList_AddImage(WDL, v.Image, X, Y,
                                                    X + v.Width, Y + v.Width, nil, nil, nil, nil,
                                                    Clr_VA or v.Clr or 0x999999aa)
                                            end



                                            if v.AdjustingX or v.AdjustingY then
                                                local l = 4

                                                r.ImGui_DrawList_AddLine(WDL, x - l, y - l, x + l,
                                                    y + l, 0xffffffdd)
                                                r.ImGui_DrawList_AddLine(WDL, x - l, y + l, x + l,
                                                    y - l, 0xffffffdd)
                                            end
                                        elseif v.Type == 'Image' and v.Image then
                                            local w, h = r.ImGui_Image_GetSize(v.Image)
                                            local w, h = (v.Width or w), (v.Height or h)
                                            if v.Width_VA and v.Width_VA ~= 0 then
                                                w = (v.Width or w) *
                                                    v.Width_VA * Prm.V
                                            end
                                            if v.Height_VA and v.Height_VA ~= 0 then
                                                h = (v.Height or h) *
                                                    v.Height_VA * Prm.V
                                            end
                                            local function AddImage(X_Gap, Y_Gap, none, RptClr)
                                                r.ImGui_DrawList_AddImage(WDL, v.Image, x + X_Gap,
                                                    y + (Y_Gap or 0), x + w + X_Gap,
                                                    y + h + (Y_Gap or 0), 0, 0, 1, 1,
                                                    RptClr or Clr_VA or v.Clr)
                                            end


                                            Repeat(v.Repeat, v.Repeat_VA, v.X_Gap or 0, v.Y_Gap or 0,
                                                AddImage, nil, v.RPT_Clr, v.Clr)
                                        elseif v.Type == 'Gain Reduction Text' and not FX[FxGUID].DontShowGR then 
                                            local GR = round(GR, 1) 
                                            r.ImGui_DrawList_AddTextEx(WDL, Arial_12, 12 , x, y , v.Clr or 0xffffffff, GR or '' ) 
                                        end
                                    end
                                end
                                r.ImGui_DrawListSplitter_Merge(DL_SPLITER)
                                --Try another method: use undo history to detect if user has changed a preset, if so, unlink all params
                                --[[ if r.TrackFX_GetOpen(LT_Track, FX_Idx) and focusedFXState==1 and FX_Index_FocusFX==FX_Idx then

                                    if FX[FxGUID].Morph_ID and not FP.UnlinkedModTable then
                                        _,TrackStateChunk, FXStateChunk, FP.UnlinkedModTable= GetParmModTable(LT_TrackNum, FX_Idx, Prm.Num, TableIndex_Str)
                                        Unlink_Parm (trackNumOfFocusFX, FX_Idx, Prm.Num ) -- Use native API instead
                                        FocusedFX = FX_Idx
                                    end
                                elseif focusedFXState==0 and UnlinkedModTable then

                                end --FX_Index_FocusFX
                                if FP.UnlinkedModTable then
                                    if not r.TrackFX_GetOpen(LT_Track, FocusedFX) then -- if the fx is closed
                                        Link_Param_to_CC(LT_TrackNum, FocusedFX, Prm.Num, true, true, -101, nil, -1, 160, FX[FxGUID].Morph_ID, UnlinkedModTable['PARAMOD_BASELINE'], UnlinkedModTable['PARMLINK_SCALE']) Use native r.TrackFX_SetNamedConfigParm instead
                                        FocusedFX=nil      FP.UnlinkedModTable = nil 
                                    end
                                end ]]
                            end
                            if r.ImGui_IsItemClicked(ctx, 1) and Mods == 0 and not AssigningMacro then
                                local draw_list = r.ImGui_GetForegroundDrawList(ctx)
                                local mouse_pos = { r.ImGui_GetMousePos(ctx) }
                                local click_pos = { r.ImGui_GetMouseClickedPos(ctx, 0) }
                                r.ImGui_DrawList_AddLine(draw_list, click_pos[1], click_pos[2], mouse_pos[1], mouse_pos[2], 0xB62424FF, 4.0)  -- Draw a line between the button and the mouse cursor                                          
                                local P_Num = Prm.Num
                                lead_fxid = FX_Idx -- storing the original fx id
                                fxidx = FX_Idx -- to prevent an error in layout editor function by not changing FX_Idx itself
                                lead_paramnumber = P_Num      
                                local ret, _ = r.TrackFX_GetNamedConfigParm(LT_Track, lead_fxid, "parent_container") 
                                local rev = ret                       
                                while rev do -- to get root parent container id
                                root_container = fxidx
                                rev, fxidx = r.TrackFX_GetNamedConfigParm(LT_Track, fxidx, "parent_container")
                                end     
                                if ret then       -- new fx and parameter                   
                                    local rv, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.add." .. lead_fxid .. "." .. lead_paramnumber)
                                    lead_fxid = root_container
                                    lead_paramnumber = buf
                                end                                                                                                    
                            end
                            if r.ImGui_IsItemClicked(ctx, 1) and Mods == Shift then
                                local P_Num = Prm.Num
                                local rv, bf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus")
                                if bf == "15" then -- reset FX Devices' modulation bus/chan                                  
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 0) -- reset bus and channel because it does not update automatically although in parameter linking midi_* is not available
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 1) 
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -1) 
                                    r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 0)
                                    if FX[FxGUID][Fx_P].ModAMT then
                                        for Mc = 1, 8, 1 do
                                            if FX[FxGUID][Fx_P].ModAMT[Mc] then
                                                FX[FxGUID][Fx_P].ModAMT[Mc] = 0
                                            end
                                        end
                                    end                                                    
                                end
                                if lead_fxid ~= nil then   
                                    follow_fxid = FX_Idx -- storing the original fx id
                                    fxidx = FX_Idx -- to prevent an error in layout editor function by not changing FX_Idx itself
                                    follow_paramnumber = P_Num      
                                    ret, _ = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "parent_container")
                                    local rev = ret                            
                                    while rev do -- to get root parent container id
                                    root_container = fxidx
                                    rev, fxidx = r.TrackFX_GetNamedConfigParm(LT_Track, fxidx, "parent_container")
                                    end
                                    if ret then  -- fx inside container  
                                        local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)                  
                                        if retval then -- toggle off and remove map
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.active", 0)
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.effect", -1) 
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.param", -1) 
                                            local rv, container_id = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "parent_container")
                                            while rv do -- removing map
                                            _, buf = r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)
                                            r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "param." .. buf .. ".container_map.delete")
                                            rv, container_id = r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "parent_container")
                                            end
                                        else  -- new fx and parameter             
                                            local rv, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.add." .. follow_fxid .. "." .. follow_paramnumber) -- map to the root
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.active", 1)
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.effect", lead_fxid) 
                                            r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.param", lead_paramnumber) 
                                        end
                                    else -- not inside container
                                        local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false)
                                        if retval and buf == "1" then -- toggle off
                                            value = 0
                                            lead_fxid = -1
                                            lead_paramnumber = -1
                                        else
                                            value = 1
                                        end
                                        r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.active", value)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.effect", lead_fxid) 
                                        r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.param", lead_paramnumber) 
                                    end
                                end  
                            end 
                            if r.ImGui_IsItemClicked(ctx, 1) and Mods == Ctrl and not AssigningMacro then
                                r.ImGui_OpenPopup(ctx, '##prm Context menu' .. FP.Num)
                            end
                            if r.ImGui_BeginPopup(ctx, '##prm Context menu' .. (FP.Num or 0)) then
                                if r.ImGui_Selectable(ctx, 'Toggle Add Parameter to Envelope', false) then
                                    local env = r.GetFXEnvelope(LT_Track, FX_Idx, Prm.Num, false) -- Check if envelope is on
                                    if env == nil then  -- Envelope is off
                                        local env = r.GetFXEnvelope(LT_Track, FX_Idx, Prm.Num, true) -- true = Create envelope
                                    else -- Envelope is on
                                        local rv, EnvelopeStateChunk = r.GetEnvelopeStateChunk(env, "", false)
                                        if string.find(EnvelopeStateChunk, "VIS 1") then -- VIS 1 = visible, VIS 0 = invisible
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 1", "VIS 0")
                                            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
                                        else -- on but invisible
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ACT 0", "ACT 1")
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 0", "VIS 1")
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ARM 0", "ARM 1")
                                            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
                                        end
                                    end
                                    r.TrackList_AdjustWindows(false)
                                    r.UpdateArrange()
                                end
                                if r.ImGui_Selectable(ctx, 'Remove Envelope', false) then
                                    local env = r.GetFXEnvelope(LT_Track, FX_Idx, Prm.Num, false) -- Check if envelope is on
                                    if env == nil then  -- Envelope is off
                                        local nothing
                                    else -- Envelope is on
                                        local rv, EnvelopeStateChunk = r.GetEnvelopeStateChunk(env, "", false)
                                        if string.find(EnvelopeStateChunk, "ACT 1") then
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ACT 1", "ACT 0")
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 1", "VIS 0")
                                            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ARM 1", "ARM 0")
                                            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
                                        end
                                    end
                                    r.TrackList_AdjustWindows(false)
                                    r.UpdateArrange()
                                end
                                if r.ImGui_Selectable(ctx, 'Toggle Add Audio Control Signal (Sidechain)') then
                                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".acs.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false) 
                                    if retval and buf == "1" then -- Toggle
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".acs.active", 0)
                                    else
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".acs.active", 1)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".acs.chan", 1)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".acs.stereo", 1)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".mod.visible", 1)
                                    end  
                                end
                                if r.ImGui_Selectable(ctx, 'Toggle Add LFO') then
                                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".lfo.active") 
                                    if retval and buf == "1" then
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".lfo.active", 0)  
                                    else
                                         r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".lfo.active", 1)      
                                         r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".mod.visible", 1) 
                                    end                                              
                                end
                                if r.ImGui_Selectable(ctx, 'Toggle Add CC Link') then
                                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.active") 
                                    local rv, bf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.midi_bus") 
                                    if bf == "15" then
                                        value = 1
                                        local retval, retvals_csv = r.GetUserInputs('Set CC value', 2, 'CC value(CC=0_119/14bit=0_31),14bit (yes=1/no=0)', '0,0') -- For 14 bit, 128 + CC# is plink.midi_msg2 value, e.g. 02/34 become 130 (128-159)
                                        local input1val, input2val = retvals_csv:match("([^,]+),([^,]+)")
                                        if input2val == nil then
                                            retvals = nil -- To make global retvals nil, when users choose cancel or close the window 
                                        end
                                        if input2val ~= nil then 
                                            if type(input1val) == "string" then
                                                local input1check = tonumber(input1val)
                                                local input2check = tonumber(input2val)
                                                if input1check and input2check then
                                                  input1val = input1check
                                                  input2val = input2check
                                                else
                                                  error('Only enter a number')
                                                end 
                                            end    
                                        local input1val = tonumber(input1val)
                                        local input2val = tonumber(input2val)                                                         
                                            if input2val < 0 then  
                                                input2val = 0
                                            elseif input2val > 1 then
                                                input2val = 1
                                            end
                                            if input1val < 0 then  
                                                input1val = 0
                                            elseif input2val == 0 and input1val > 119 then
                                                input1val = 119
                                            elseif input2val == 1 and input1val > 31 then
                                                input1val = 31
                                            end
                                            input2val = input2val * 128
                                            retvals = input1val + input2val
                                        end
                                        if FX[FxGUID][Fx_P].ModAMT and retvals ~= nil then
                                            for Mc = 1, 8, 1 do
                                                if FX[FxGUID][Fx_P].ModAMT[Mc] then
                                                    FX[FxGUID][Fx_P].ModAMT[Mc] = 0
                                                end
                                            end
                                        end
                                    elseif retval and buf == "1" then
                                        value = 0
                                    else
                                        value = 1
                                        local retval, retvals_csv = r.GetUserInputs('Set CC value', 2, 'CC value(CC=0_119/14bit=0_31),14bit (yes=1/no=0)', '0,0') -- retvals_csv returns "input1,input2"
                                        local input1val, input2val = retvals_csv:match("([^,]+),([^,]+)")
                                        if input2val == nil then
                                            retvals = nil -- To make global retvals nil, when users choose cancel or close the window 
                                        end
                                        if input2val ~= nil then
                                            if type(input1val) == "string" then
                                                local input1check = tonumber(input1val)
                                                local input2check = tonumber(input2val)
                                                if input1check and input2check then
                                                  input1val = input1check
                                                  input2val = input2check
                                                else
                                                  error('Only enter a number')
                                                end 
                                            end 
                                        local input1val = tonumber(input1val)
                                        local input2val = tonumber(input2val)                                                          
                                            if input2val < 0 then  
                                                input2val = 0
                                            elseif input2val > 1 then
                                                input2val = 1
                                            end
                                            if input1val < 0 then  
                                                input1val = 0
                                            elseif input2val == 0 and input1val > 119 then
                                                input1val = 119
                                            elseif input2val == 1 and input1val > 31 then
                                                input1val = 31
                                            end
                                            input2val = input2val * 128
                                            retvals = input1val + input2val
                                        end
                                    end
                                    if retvals ~= nil then
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.active", value)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.effect", -100) 
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.param", -1)   
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.midi_bus", 0)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.midi_chan", 1)
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.midi_msg", 176)  
                                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".plink.midi_msg2", retvals) 
                                    end                                                      
                                end
                                if r.ImGui_Selectable(ctx, 'Toggle Open Modulation/Link Window') then
                                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".mod.visible") 
                                    if retval and buf == "1" then
                                        value = 0
                                    else
                                        value = 1
                                    end
                                    local window = r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..Prm.Num..".mod.visible", value)                                                     
                                end
                                r.ImGui_EndPopup(ctx)
                            end
                        end
                    end -- Rpt for every param


                    if FX.LayEdit then
                        if LE.DragY > LE.GridSize or LE.DragX > LE.GridSize or LE.DragY < -LE.GridSize or LE.DragX < -LE.GridSize then
                            r.ImGui_ResetMouseDragDelta(ctx)
                        end
                    end


                    if r.ImGui_IsMouseHoveringRect(ctx, Win_L, Win_T, Win_R, Win_B) and
                        r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_RootAndChildWindows())
                    then
                        if ClickOnAnyItem == nil and LBtnRel and AdjustPrmWidth ~= true and Mods == 0 then
                            LE.Sel_Items = {};
                        elseif ClickOnAnyItem and LBtnRel then
                            ClickOnAnyItem = nil
                        elseif AdjustPrmWidth == true then
                            AdjustPrmWidth = nil
                        end
                    end




                    if FX[FxGUID].Round then r.ImGui_PopStyleVar(ctx) end
                    if FX[FxGUID].GrbRound then r.ImGui_PopStyleVar(ctx) end



                    if (FX.LayEdit == FxGUID or Draw.DrawMode[FxGUID] == true) and Mods ~= Apl then
                        r.ImGui_EndDisabled(ctx)
                    end
                end




                for i, v in pairs(PluginScripts) do
                    local FX_Name = FX_Name


                    if FX_Name:find(v) then
                        r.SetExtState('FXD', 'Plugin Script FX_Id', FX_Idx, false)
                        PluginScript.FX_Idx = FX_Idx
                        PluginScript.Guid = FxGUID
                        dofile(pluginScriptPath .. '/' .. v .. '.lua')
                    end
                end
                --PluginScript.FX_Idx = FX_Idx
                -- PluginScript.Guid = FXGUID[FX_Idx]
                --require("src.FX Layout Plugin Scripts.Pro C 2")
                -- require("src.FX Layout Plugin Scripts.Pro Q 3")



                if FX.Enable[FX_Idx] == false then
                    r.ImGui_DrawList_AddRectFilled(WDL, Win_L, Win_T, Win_R, Win_B, 0x00000088)
                end

                --[[ if r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_RootAndChildWindows()) then 
                    DisableScroll = nil 
                else DisableScroll = true 
                end ]]

                r.ImGui_Dummy(ctx, 0, dummyH)
                if r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_ChildWindows()) then 
                    if FX_Name == 'Container' --[[ and FX_Idx < 0x2000000 ]]  and not Tab_Collapse_Win then 
                        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Tab())  then
                            CollapseIfTab(FxGUID, FX_Idx)
                            Tab_Collapse_Win = true 
                            NeedRetrieveLayout = true 

                        end
                    end
                end

                HoverWindow = r.ImGui_GetWindowSize(ctx)

                r.ImGui_EndChild(ctx)

            end


            
            r.ImGui_PopStyleVar(ctx)-- styleVar ScrollBar
        end


        --------------------------------------------------------------------------------------
        --------------------------------------Draw Mode --------------------------------------
        --------------------------------------------------------------------------------------

        --------------------FX Devices--------------------

        r.ImGui_PopStyleColor(ctx, poptimes) -- -- PopColor #1 FX Window
        r.ImGui_SameLine(ctx, nil, 0)





        


        r.ImGui_EndGroup(ctx)
    end
    if BlinkFX == FX_Idx then BlinkFX = BlinkItem(0.2, 2, BlinkFX) end

    return HoverWindow
end --of Create fx window function




function get_fx_id_from_container_path(tr, idx1, ...)
    local sc,rv = reaper.TrackFX_GetCount(tr)+1, 0x2000000 + idx1
    for i,v in ipairs({...}) do
      local ccok, cc = reaper.TrackFX_GetNamedConfigParm(tr, rv, 'container_count')
      if ccok ~= true then return nil end
      rv = rv + sc * v
      sc = sc * (1+tonumber(cc))
    end
    return rv
end

function get_container_path_from_fx_id(tr, fxidx) -- returns a list of 1-based IDs from a fx-address
    if fxidx & 0x2000000 then
      local ret = { }
      local n = reaper.TrackFX_GetCount(tr)
      local curidx = (fxidx - 0x2000000) % (n+1)
      local remain = math.floor((fxidx - 0x2000000) / (n+1))
      if curidx < 1 then return nil end -- bad address
  
      local addr, addr_sc = curidx + 0x2000000, n + 1
      while true do
        local ccok, cc = reaper.TrackFX_GetNamedConfigParm(tr, addr, 'container_count')
        if not ccok then return nil end -- not a container
        ret[#ret+1] = curidx
        n = tonumber(cc)
        if remain <= n then if remain > 0 then ret[#ret+1] = remain end return ret end
        curidx = remain % (n+1)
        remain = math.floor(remain / (n+1))
        if curidx < 1 then return nil end -- bad address
        addr = addr + addr_sc * curidx
        addr_sc = addr_sc * (n+1)
      end
    end
    return { fxid+1 }
end

function fx_map_parameter(tr, fxidx, parmidx) -- maps a parameter to the top level parent, returns { fxidx, parmidx }
    local path = get_container_path_from_fx_id(tr, fxidx)
    if not path then return nil end
    while #path > 1 do
      fxidx = path[#path]
      table.remove(path)
      local cidx = get_fx_id_from_container_path(tr,table.unpack(path))
      if cidx == nil then return nil end
      local i, found = 0, nil
      while true do
        local rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",i))
        if not rok then break end
        if tonumber(r) == fxidx - 1 then
          rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",i))
          if not rok then break end
          if tonumber(r) == parmidx then found = true parmidx = i break end
        end
        i = i + 1
      end
      if not found then
        -- add a new mapping
        local rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,"container_map.add")
        if not rok then return nil end
        r = tonumber(r)
        reaper.TrackFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",r),tostring(fxidx - 1))
        reaper.TrackFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",r),tostring(parmidx))
        parmidx = r
      end
    end
    return fxidx, parmidx
end

--------------==  Space between FXs--------------------
function AddSpaceBtwnFXs(FX_Idx, SpaceIsBeforeRackMixer, AddLastSpace, LyrID, SpcIDinPost, FxGUID_Container, AdditionalWidth, FX_Idx_in_Container)

    local SpcIsInPre, Hide, SpcInPost, MoveTarget
    local WinW

    if FX_Idx == 0 and r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) ~= -1 then FX_Idx = 1 end

    TblIdxForSpace = FX_Idx .. tostring(SpaceIsBeforeRackMixer)
    FXGUID_To_Check_If_InLayer = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
    if Trk[TrkID].PreFX[1] then
        local offset
        if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) ~= -1 then offset = 1 else offset = 0 end
        if SpaceIsBeforeRackMixer == 'End of PreFX' then
            SpcIsInPre = true
            if Trk[TrkID].PreFX_Hide then Hide = true end
            MoveTarget = FX_Idx + 1
        elseif FX_Idx + 1 - offset <= #Trk[TrkID].PreFX and SpaceIsBeforeRackMixer ~= 'End of PreFX' then
            SpcIsInPre = true; if Trk[TrkID].PreFX_Hide then Hide = true end
        end
    end
    --[[ if SpaceIsBeforeRackMixer == 'SpcInPost' or SpaceIsBeforeRackMixer == 'SpcInPost 1st spc' then
        SpcInPost = true
        if PostFX_LastSpc == 30 then Dvdr.Spc_Hover[TblIdxForSpace] = 30 end
    end ]]
    local ClrLbl = FX_Idx .. (tostring(SpaceIsBeforeRackMixer) or '')


    Dvdr.Clr[ClrLbl] = Space_Between_FXs
    Dvdr.Width[TblIdxForSpace] = Dvdr.Width[TblIdxForSpace] or 0
    if FX_Idx == 0 and DragDroppingFX and not SpcIsInPre then
        if r.ImGui_IsMouseHoveringRect(ctx, Cx_LeftEdge + 10, Cy_BeforeFXdevices, Cx_LeftEdge + 25, Cy_BeforeFXdevices + 220) and DragFX_ID ~= 0 then
            Dvdr.Width[TblIdxForSpace] = Df.Dvdr_Width
        end
    end

    if FX_Idx == RepeatTimeForWindows then
        Dvdr.Width[TblIdxForSpace] = 15
    end

    if FX_Idx_OpenedPopup == (FX_Idx or 0) .. (tostring(SpaceIsBeforeRackMixer) or '') then
        Dvdr.Clr[ClrLbl] = Clr.Dvdr.Active
    else
        Dvdr.Clr[ClrLbl] = Dvdr.Clr[ClrLbl] or Clr.Dvdr.In_Layer
    end

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(),  Dvdr.Clr[ClrLbl])

    local w = 10 + Dvdr.Width[TblIdxForSpace] + (Dvdr.Spc_Hover[TblIdxForSpace] or 0) + (AdditionalWidth or 0)
    local _, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx)



    -- StyleColor For Space Btwn Fx Windows
    if not Hide then
        if r.ImGui_BeginChildFrame(ctx, '##SpaceBetweenWindows' .. FX_Idx .. tostring(SpaceIsBeforeRackMixer) .. 'Last SPC in Rack = ' .. tostring(AddLastSPCinRack), 10, 220, r.ImGui_WindowFlags_NoScrollbar()+r.ImGui_WindowFlags_NoScrollWithMouse()+r.ImGui_WindowFlags_NoNavFocus()+r.ImGui_WindowFlags_NoNav()) then
            --HOVER_RECT = r.ImGui_IsWindowHovered(ctx,  r.ImGui_HoveredFlags_RectOnly())
            HoverOnWindow = r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
            WinW  = r.ImGui_GetWindowSize(ctx)


            if HoverOnWindow == true and Dragging_TrueUntilMouseUp ~= true and DragDroppingFX ~= true and AssignWhichParam == nil and Is_ParamSliders_Active ~= true and Wet.ActiveAny ~= true and Knob_Active ~= true and not Dvdr.JustDroppedFX and LBtn_MousdDownDuration < 0.2 then
                Dvdr.Spc_Hover[TblIdxForSpace] = Df.Dvdr_Hvr_W
                if DebugMode then
                    tooltip('FX_Idx :' .. FX_Idx ..'\n Pre/Post/Norm : ' ..
                        tostring(SpaceIsBeforeRackMixer) .. '\n SpcIDinPost: ' .. tostring(SpcIDinPost).. '\n AddLastSpace = '..(AddLastSpace or 'nil') ..'\n AdditionalWidth = '..(AdditionalWidth or 'nil') )
                end
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), CLR_BtwnFXs_Btn_Hover)
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), CLR_BtwnFXs_Btn_Active)

                local x, y = r.ImGui_GetCursorScreenPos(ctx)
                r.ImGui_SetCursorScreenPos(ctx, x, Glob.WinT)
                BTN_Btwn_FXWindows = r.ImGui_Button(ctx, '##Button between Windows', 99, 217)
                FX_Insert_Pos = FX_Idx

                if BTN_Btwn_FXWindows then
                    FX_Idx_OpenedPopup = FX_Idx .. (tostring(SpaceIsBeforeRackMixer) or '')
                    r.ImGui_OpenPopup(ctx, 'Btwn FX Windows' .. FX_Idx)
                end
                r.ImGui_PopStyleColor(ctx, 2)
                Dvdr.RestoreNormWidthWait[FX_Idx] = 0
            else
                Dvdr.RestoreNormWidthWait[FX_Idx] = (Dvdr.RestoreNormWidthWait[FX_Idx] or 0) + 1
                if Dvdr.RestoreNormWidthWait[FX_Idx] >= 8 then
                    Dvdr.Spc_Hover[TblIdxForSpace] = Dvdr_Hvr_W
                    Dvdr.RestoreNormWidthWait[FX_Idx] = 0
                end
            end



            AddFX_Menu(FX_Idx)
            

            r.ImGui_EndChildFrame(ctx)
        end
    end
    r.ImGui_PopStyleColor(ctx)
    local FXGUID_FX_Idx = r.TrackFX_GetFXGUID(LT_Track, FX_Idx - 1)


    function MoveFX(DragFX_ID, FX_Idx, isMove, AddLastSpace)
        local FxGUID_DragFX = FXGUID[DragFX_ID] or r.TrackFX_GetFXGUID(LT_Track, DragFX_ID)

        local AltDest, AltDestLow, AltDestHigh, DontMove

        if SpcInPost then SpcIsInPre = false end
        
        if SpcIsInPre then
            if not tablefind(Trk[TrkID].PreFX, FxGUID_DragFX) then -- if fx is not in pre fx
                if SpaceIsBeforeRackMixer == 'End of PreFX' then
                    local offset = 0
                    if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) ~= -1 then offset = -1 end

                    table.insert(Trk[TrkID].PreFX, #Trk[TrkID].PreFX + 1, FxGUID_DragFX)
                    --r.TrackFX_CopyToTrack(LT_Track, DragFX_ID, LT_Track, FX_Idx + 1, true)
                    DontMove = true
                else
                    table.insert(Trk[TrkID].PreFX, FX_Idx + 1, FxGUID_DragFX)
                end
            else -- if fx is in pre fx
                local offset = 0
                if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) ~= -1 then offset = -1 end
                if FX_Idx < DragFX_ID then -- if drag towards left
                    table.remove(Trk[TrkID].PreFX, DragFX_ID + 1 + offset)
                    table.insert(Trk[TrkID].PreFX, FX_Idx + 1 + offset, FxGUID_DragFX)
                elseif SpaceIsBeforeRackMixer == 'End of PreFX' then
                    table.insert(Trk[TrkID].PreFX, #Trk[TrkID].PreFX + 1, FxGUID_DragFX)
                    table.remove(Trk[TrkID].PreFX, DragFX_ID + 1 + offset)
                    --move fx down
                else
                    table.insert(Trk[TrkID].PreFX, FX_Idx + 1 + offset, FxGUID_DragFX)
                    table.remove(Trk[TrkID].PreFX, DragFX_ID + 1 + offset)
                end
            end

            for i, v in pairs(Trk[TrkID].PreFX) do
                r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' ..
                    i, v, true)
            end
            if tablefind(Trk[TrkID].PostFX, FxGUID_DragFX) then
                table.remove(Trk[TrkID].PostFX, tablefind(Trk[TrkID].PostFX, FxGUID_DragFX))
            end
            FX.InLyr[FxGUID_DragFX] = nil
        elseif SpcInPost then
            local offset

            if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) == -1 then offset = -1 else offset = 0 end

            if not tablefind(Trk[TrkID].PostFX, FxGUID_DragFX) then -- if fx is not yet in post-fx chain
                InsertToPost_Src = DragFX_ID + offset + 1

                InsertToPost_Dest = SpcIDinPost


                if tablefind(Trk[TrkID].PreFX, FxGUID_DragFX) then
                    table.remove(Trk[TrkID].PreFX, tablefind(Trk[TrkID].PreFX, FxGUID_DragFX))
                end
            else                                -- if fx is already in post-fx chain
                local IDinPost = tablefind(Trk[TrkID].PostFX, FxGUID_DragFX)
                if SpcIDinPost <= IDinPost then -- if drag towards left
                    table.remove(Trk[TrkID].PostFX, IDinPost)
                    table.insert(Trk[TrkID].PostFX, SpcIDinPost, FxGUID_DragFX)
                    table.insert(MovFX.ToPos, FX_Idx + 1)
                else
                    table.insert(Trk[TrkID].PostFX, SpcIDinPost, Trk[TrkID].PostFX[IDinPost])
                    table.remove(Trk[TrkID].PostFX, IDinPost)
                    table.insert(MovFX.ToPos, FX_Idx)
                end
                DontMove = true
                table.insert(MovFX.FromPos, DragFX_ID)
            end
            FX.InLyr[FxGUID_DragFX] = nil
        else -- if space is not in pre or post
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. DragFX_ID, '', true)
            if not MoveFromPostToNorm then
                if tablefind(Trk[TrkID].PreFX, FxGUID_DragFX) then
                    table.remove(Trk[TrkID].PreFX,
                    tablefind(Trk[TrkID].PreFX, FxGUID_DragFX))
                end
            end
            if tablefind(Trk[TrkID].PostFX, FxGUID_DragFX) then
                table.remove(Trk[TrkID].PostFX,
                    tablefind(Trk[TrkID].PostFX, FxGUID_DragFX))
            end
        end
        for i = 1, #Trk[TrkID].PostFX + 1, 1 do
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX ' .. i, Trk[TrkID].PostFX[i] or '',
                true)
        end
        for i = 1, #Trk[TrkID].PreFX + 1, 1 do
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. i, Trk[TrkID].PreFX[i] or '',
                true)
        end
        if not DontMove then
            if FX_Idx ~= RepeatTimeForWindows and SpaceIsBeforeRackMixer ~= 'End of PreFX' then
                --[[ if ((FX.Win_Name_S[FX_Idx]or''):find('Pro%-Q 3') or (FX.Win_Name_S[FX_Idx]or''):find('Pro%-C 2')) and not tablefind (Trk[TrkID].PreFX, FXGUID[FX_Idx]) then
                    AltDestLow = FX_Idx-1
                end ]]
                if (FX.Win_Name_S[FX_Idx] or ''):find('Pro%-C 2') then
                    AltDestHigh = FX_Idx - 1
                end
                FX_Idx = tonumber(FX_Idx)
                DragFX_ID = tonumber(DragFX_ID)

                if FX_Idx > DragFX_ID and FX_Idx < 0x2000000 then offset = 1 end


                table.insert(MovFX.ToPos, AltDestLow or FX_Idx - (offset or 0))
                table.insert(MovFX.FromPos, DragFX_ID)
            elseif FX_Idx == RepeatTimeForWindows and AddLastSpace == 'LastSpc' or SpaceIsBeforeRackMixer == 'End of PreFX' then
                local offset

                if Trk[TrkID].PostFX[1] then offset = #Trk[TrkID].PostFX end
                table.insert(MovFX.ToPos, FX_Idx - (offset or 0))
                table.insert(MovFX.FromPos, DragFX_ID)
            else
                
                table.insert(MovFX.ToPos, FX_Idx - (offset or 0))
                table.insert(MovFX.FromPos, DragFX_ID)
            end
        end
        if isMove == false then
            NeedCopyFX = true
            DropPos = FX_Idx
        end
    end

    function MoveFXwith1PreFXand1PosFX(DragFX_ID, FX_Idx, Undo_Lbl)
        r.Undo_BeginBlock()
        table.remove(Trk[TrkID].PreFX, tablefind(Trk[TrkID].PreFX, FxGUID_DragFX))
        for i = 1, #Trk[TrkID].PreFX + 1, 1 do
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. i, Trk[TrkID].PreFX[i] or '',
                true)
        end
        table.remove(Trk[TrkID].PostFX, tablefind(Trk[TrkID].PostFX, FxGUID_DragFX))
        for i = 1, #Trk[TrkID].PostFX + 1, 1 do
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX ' .. i, Trk[TrkID].PostFX[i] or '',
                true)
        end
        if FX_Idx ~= RepeatTimeForWindows then
            if DragFX_ID > FX_Idx then
                table.insert(MovFX.FromPos, DragFX_ID)
                table.insert(MovFX.ToPos, FX_Idx)
                table.insert(MovFX.FromPos, DragFX_ID)
                table.insert(MovFX.ToPos, FX_Idx)
                table.insert(MovFX.FromPos, DragFX_ID + 1)
                table.insert(MovFX.ToPos, FX_Idx + 2)


                --[[ r.TrackFX_CopyToTrack( LT_Track, DragFX_ID, LT_Track, FX_Idx, true )
                r.TrackFX_CopyToTrack( LT_Track, DragFX_ID, LT_Track, FX_Idx, true )
                r.TrackFX_CopyToTrack( LT_Track, DragFX_ID+1, LT_Track, FX_Idx+2, true ) ]]
            elseif FX_Idx > DragFX_ID then
                table.insert(MovFX.FromPos, DragFX_ID)
                table.insert(MovFX.ToPos, FX_Idx - 1)
                table.insert(MovFX.FromPos, DragFX_ID - 1)
                table.insert(MovFX.ToPos, FX_Idx - 2)
                table.insert(MovFX.FromPos, DragFX_ID - 1)
                table.insert(MovFX.ToPos, FX_Idx - 1)

                --[[ r.TrackFX_CopyToTrack( LT_Track, DragFX_ID, LT_Track, FX_Idx-1 , true )
                r.TrackFX_CopyToTrack( LT_Track, DragFX_ID-1, LT_Track, FX_Idx-2 , true )
                r.TrackFX_CopyToTrack( LT_Track, DragFX_ID-1, LT_Track, FX_Idx-1 , true ) ]]
            end
        else
            if AddLastSpace == 'LastSpc' then
                r.TrackFX_CopyToTrack(LT_Track, DragFX_ID, LT_Track, FX_Idx, true)
                r.TrackFX_CopyToTrack(LT_Track, DragFX_ID - 1, LT_Track, FX_Idx - 2, true)
            end
        end
        r.Undo_EndBlock(Undo_Lbl, 0)
    end

    function MoveFXwith1PreFX(DragFX_ID, FX_Idx, Undo_Lbl)
        r.Undo_BeginBlock()
        if FX_Idx ~= RepeatTimeForWindows then
            if payload > FX_Idx then
                r.TrackFX_CopyToTrack(LT_Track, payload, LT_Track, FX_Idx, true)
                r.TrackFX_CopyToTrack(LT_Track, payload, LT_Track, FX_Idx, true)
            elseif FX_Idx > payload then
                r.TrackFX_CopyToTrack(LT_Track, payload, LT_Track, FX_Idx - 1, true)
                r.TrackFX_CopyToTrack(LT_Track, payload - 1, LT_Track, FX_Idx - 2, true)
            end
        else
            if AddLastSpace == 'LastSpc' then
                r.TrackFX_CopyToTrack(LT_Track, payload, LT_Track, FX_Idx, true)
                r.TrackFX_CopyToTrack(LT_Track, payload - 1, LT_Track, FX_Idx - 2, true)
            end
        end
        r.Undo_EndBlock(Undo_Lbl, 0)
    end

    ---  if the space is in FX layer
    if FX.InLyr[FXGUID_To_Check_If_InLayer] == FXGUID_RackMixer and SpaceIsBeforeRackMixer == false or AddLastSPCinRack == true then
        Dvdr.Clr[ClrLbl] = Clr.Dvdr.In_Layer
        FXGUID_of_DraggingFX = r.TrackFX_GetFXGUID(LT_Track, DragFX_ID or 0)

        if DragFX_ID == FX_Idx or DragFX_ID == FX_Idx - 1 and FX.InLyr[FXGUID_of_DraggingFX] == FXGUID[FX_Idx] then
            Dvdr.Width[TblIdxForSpace] = 0
        else
            if r.ImGui_BeginDragDropTarget(ctx) then
                FxDroppingTo = FX_Idx
                ----- Drag Drop FX -------
                dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX_Drag')
                if FxGUID == FxGUID_DragFX then
                    Dvdr.Width[TblIdxForSpace] = 0
                else
                    Dvdr.Width[TblIdxForSpace] = Df.Dvdr_Width
                end

                r.ImGui_SameLine(ctx, 100, 10)


                if dropped and Mods == 0 then
                    DropFXtoLayer(FX_Idx, LyrID)
                    Dvdr.Width[TblIdxForSpace] = 0
                    FxDroppingTo = nil
                elseif dropped and Mods == Apl then
                    DragFX_Src = DragFX_ID

                    if DragFX_ID > FX_Idx then DragFX_Dest = FX_Idx - 1 else DragFX_Dest = FX_Idx end
                    DropToLyrID = LyrID
                    DroptoRack = FXGUID_RackMixer
                    --MoveFX(DragFX_Src, DragFX_Dest ,false )

                    Dvdr.Width[TblIdxForSpace] = 0
                    FxDroppingTo = nil
                end
                ----------- Add FX ---------------
                if Payload_Type == 'DND ADD FX' then
                    DndAddFXfromBrowser_TARGET(FX_Idx, ClrLbl) -- fx layer
                end

                

                r.ImGui_EndDragDropTarget(ctx)
            else
                Dvdr.Width[TblIdxForSpace] = 0
                FxDroppingTo = nil
            end
        end
        r.ImGui_SameLine(ctx, 100, 10)
    elseif SpaceIsBeforeRackMixer == 'SpcInBS' then
        if DragFX_ID == FX_Idx or DragFX_ID == FX_Idx - 1 and FX.InLyr[FXGUID_of_DraggingFX] == FXGUID[FX_Idx] then
            Dvdr.Width[TblIdxForSpace] = 0
        else
            if r.ImGui_BeginDragDropTarget(ctx) then
                FxDroppingTo = FX_Idx
                dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX_Drag')
                if FxGUID == FxGUID_DragFX then
                    Dvdr.Width[TblIdxForSpace] = 0
                else
                    Dvdr.Width[TblIdxForSpace] = Df.Dvdr_Width
                end

                r.ImGui_SameLine(ctx, 100, 10)
                local ContainerIdx = tablefind(FXGUID, FxGUID_Container)
                local InsPos = math.min(FX_Idx - ContainerIdx + 1, #FX[FxGUID_Container].FXsInBS)


                if dropped and Mods == 0 then
                    local ContainerIdx = tablefind(FXGUID, FxGUID_Container)
                    local InsPos = SetMinMax(FX_Idx - ContainerIdx + 1, 1, #FX[FxGUID_Container].FXsInBS)



                    DropFXintoBS(FxGUID_DragFX, FxGUID_Container, FX[FxGUID_Container].Sel_Band,
                        DragFX_ID, FX_Idx, 'DontMove')
                    Dvdr.Width[TblIdxForSpace] = 0
                    FxDroppingTo = nil

                    MoveFX(Glob.Payload, FX_Idx + 1, true)
                elseif dropped and Mods == Apl then
                    DragFX_Src = DragFX_ID

                    if DragFX_ID > FX_Idx then DragFX_Dest = FX_Idx - 1 else DragFX_Dest = FX_Idx end
                    DropToLyrID = LyrID
                    DroptoRack = FXGUID_RackMixer
                    --MoveFX(DragFX_Src, DragFX_Dest ,false )

                    Dvdr.Width[TblIdxForSpace] = 0
                    FxDroppingTo = nil
                end
                -- Add from Sexan Add FX
                if Payload_Type == 'DND ADD FX' then
                    DndAddFXfromBrowser_TARGET(FX_Idx, ClrLbl)  -- band split
                end

                r.ImGui_EndDragDropTarget(ctx)
            else
                Dvdr.Width[TblIdxForSpace] = 0
                FxDroppingTo = nil
            end
        end
    else -- if Space is not in FX Layer
        function MoveFX_Out_Of_BS()
            for i = 0, Sel_Track_FX_Count - 1, 1 do
                if FX[FXGUID[i]].FXsInBS then -- i is Band Splitter
                    table.remove(FX[FXGUID[i]].FXsInBS, tablefind(FX[FXGUID[i]].FXsInBS, FxGUID_DragFX))
                    r.GetSetMediaTrackInfo_String(LT_Track,
                        'P_EXT: FX is in which BS' .. FxGUID_DragFX, '', true)
                    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX is in which Band' .. FXGUID
                        [DragFX_ID], '', true)
                end
            end
            FX[FxGUID_DragFX].InWhichBand = nil
        end

        if r.ImGui_BeginDragDropTarget(ctx) then

            if Payload_Type == 'FX_Drag' then


                local allowDropNext, MoveFromPostToNorm, DontAllowDrop
                local FX_Idx = FX_Idx
                if Mods == Apl then allowDropNext = true end
                if not FxGUID_DragFX then FxGUID_DragFX =DragFxGuid end 
                local rv, type, payload, is_preview, is_delivery = r.ImGui_GetDragDropPayload( ctx)


                if tablefind(Trk[TrkID].PreFX, FxGUID_DragFX) and (not SpcIsInPre or SpaceIsBeforeRackMixer == 'End of PreFX') then allowDropNext = true end
                if tablefind(Trk[TrkID].PostFX, FxGUID_DragFX) and (not SpcInPost or AddLastSpace == 'LastSpc') then
                    allowDropNext = true; MoveFromPostToNorm = true
                end
                if FX[FxGUID_DragFX].InWhichBand then allowDropNext = true end
                if not FX[FxGUID_DragFX].InWhichBand and SpaceIsBeforeRackMixer == 'SpcInBS' then allowDropNext = true end
                --[[  if (FX.Win_Name_S[DragFX_ID]or''):find('Pro%-C 2') then
                    FX_Idx = FX_Idx-1
                    if (DragFX_ID  == FX_Idx +1) or (DragFX_ID == FX_Idx-1)  then DontAllowDrop = true end
                end  ]]

                if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) ~= -1 then offset = 0 else offset = 0 end

                if (DragFX_ID + offset == FX_Idx or DragFX_ID + offset == FX_Idx - 1) and SpaceIsBeforeRackMixer ~= true and FX.InLyr[FxGUID_DragFX] == nil and not SpcInPost and not allowDropNext
                    or (Trk[TrkID].PreFX[#Trk[TrkID].PreFX] == FxGUID_DragFX and SpaceIsBeforeRackMixer == 'End of PreFX') or DontAllowDrop then
                    r.ImGui_SameLine(ctx, nil, 0)

                    Dvdr.Width[TblIdxForSpace] = 0
                    r.ImGui_EndDragDropTarget(ctx)
                else
                    HighlightSelectedItem(0xffffff22, nil, 0, L, T, R, B, h, w, 0, 0, 'GetItemRect', Foreground)

                    Dvdr.Clr[ClrLbl] = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
                    Dvdr.Width[TblIdxForSpace] = Df.Dvdr_Width

                    dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX_Drag')
                    FXGUID_To_Check_If_InLayer = r.TrackFX_GetFXGUID(LT_Track, DragFX_ID)
                    if dropped and Mods == 0 then
                        payload = tonumber(payload)
                        r.TrackFX_SetPinMappings(LT_Track, DragFX_ID, 0, 0, 1, 0)
                        r.TrackFX_SetPinMappings(LT_Track, DragFX_ID, 0, 1, 2, 0)

                        r.TrackFX_SetPinMappings(LT_Track, DragFX_ID, 1, 0, 1, 0)
                        r.TrackFX_SetPinMappings(LT_Track, DragFX_ID, 1, 1, 2, 0)

                        --[[ if FX.Win_Name_S[payload]:find('Pro%-Q 3') and not tablefind(Trk[TrkID].PostFX, FxGUID_DragFX ) and not SpcInPost and not SpcIsInPre and not tablefind(Trk[TrkID].PreFX, FxGUID_DragFX) then
                            MoveFXwith1PreFX(DragFX_ID, FX_Idx, 'Move Pro-Q 3 and it\'s analyzer')
                        else ]]
                            MoveFX(payload, FX_Idx, true, nil)
                        --[[ end ]]

                        -- Move FX Out of BandSplit
                        if FX[FxGUID_DragFX].InWhichBand then
                            for i = 0, Sel_Track_FX_Count - 1, 1 do
                                if FX[FXGUID[i]].FXsInBS then -- i is Band Splitter
                                    table.remove(FX[FXGUID[i]].FXsInBS,
                                        tablefind(FX[FXGUID[i]].FXsInBS, FxGUID_DragFX))
                                    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX is in which BS' .. FxGUID_DragFX, '', true)
                                    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX is in which Band' .. FxGUID_DragFX, '', true)
                                end
                            end
                            FX[FxGUID_DragFX].InWhichBand = nil
                        end


                        -- Move FX Out of Layer
                        if Lyr.FX_Ins[FX.InLyr[FXGUID_To_Check_If_InLayer]] ~= nil then
                            Lyr.FX_Ins[FX.InLyr[FXGUID_To_Check_If_InLayer]] = Lyr.FX_Ins[FX.InLyr[FXGUID_To_Check_If_InLayer]] - 1
                        end
                        r.SetProjExtState(0, 'FX Devices', 'FXLayer - ' .. 'is FX' .. FXGUID_To_Check_If_InLayer .. 'in layer', "")
                        FX.InLyr[FXGUID_To_Check_If_InLayer] = nil
                        Dvdr.JustDroppedFX = true
                    elseif dropped and Mods == Apl then
                        local copypos = FX_Idx + 1
                        payload = tonumber(payload)

                        if FX_Idx == 0 then copypos = 0 end
                        MoveFX(payload, copypos, false)
                    end
                    r.ImGui_SameLine(ctx, nil, 0)

                end

            elseif Payload_Type == 'FX Layer Repositioning' then -- FX Layer Repositioning
                local FXGUID_RackMixer = r.TrackFX_GetFXGUID(LT_Track, DragFX_ID)

                local lyrFxInst
                if Lyr[FXGUID_RackMixer] then
                    lyrFxInst = Lyr[FXGUID_RackMixer].HowManyFX
                else
                    lyrFxInst = 0
                end


                if (DragFX_ID - (math.max(lyrFxInst, 1)) <= FX_Idx and FX_Idx <= DragFX_ID + 1) or DragFX_ID - lyrFxInst == FX_Idx then
                    DontAllowDrop = true
                    r.ImGui_SameLine(ctx, nil, 0)
                    Dvdr.Width[TblIdxForSpace] = 0
                    r.ImGui_EndDragDropTarget(ctx)

                    --[[  ]]
                    Dvdr.Width[FX_Idx] = 0
                else --if dragging to an adequate space
                    Dvdr.Clr[ClrLbl] = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
                    dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX Layer Repositioning')
                    Dvdr.Width[TblIdxForSpace] = 30

                    if dropped then
                        RepositionFXsInContainer(FX_Idx)
                        --r.Undo_EndBlock('Undo for moving FX layer',0)
                    end
                end
            elseif Payload_Type == 'BS_Drag' then
                local Pl = tonumber(Glob.Payload)


                if SpaceIsBeforeRackMixer == 'SpcInBS' or FX_Idx == Pl or Pl + (#FX[FXGUID[Pl]].FXsInBS or 0) + 2 == FX_Idx then
                    Dvdr.Width[TblIdxForSpace] = 0
                else
                    dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'BS_Drag')
                    Dvdr.Width[TblIdxForSpace] = 30
                    if dropped then
                        RepositionFXsInContainer(FX_Idx, Glob.Payload)
                    end
                end
            elseif Payload_Type == 'DND ADD FX' then

                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)

                local dropped, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ADD FX')
                HighlightSelectedItem(0xffffff22, nil, 0, L, T, R, B, h, w, 0, 0, 'GetItemRect', Foreground)

                if dropped then
                    local FX_Idx = FX_Idx
                    if SpaceIsBeforeRackMixer == 'End of PreFX' then FX_Idx = FX_Idx + 1 end
                    
                    r.TrackFX_AddByName(LT_Track, payload, false, -1000 - FX_Idx, false)
                    local FxID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
                    local _, nm = r.TrackFX_GetFXName(LT_Track, FX_Idx)
        
                        --if in layer
                    if FX.InLyr[FXGUID_To_Check_If_InLayer] == FXGUID_RackMixer and SpaceIsBeforeRackMixer == false or AddLastSPCinRack == true then
                        DropFXtoLayerNoMove(FXGUID_RackMixer, LyrID, FX_Idx)
                    end
                    Dvdr.Clr[ClrLbl], Dvdr.Width[TblIdxForSpace] = nil, 0
                    if SpcIsInPre then
                        if SpaceIsBeforeRackMixer == 'End of PreFX' then
                            table.insert(Trk[TrkID].PreFX, FxID)
                        else
                        table.insert(Trk[TrkID].PreFX, FX_Idx + 1, FxID)
                        end
                        for i, v in pairs(Trk[TrkID].PreFX) do r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PreFX ' .. i, v,
                            true) end
                    elseif SpcInPost then
                        if r.TrackFX_AddByName(LT_Track, 'FXD Macros', 0, 0) == -1 then offset = -1 else offset = 0 end
                        table.insert(Trk[TrkID].PostFX, SpcIDinPost + offset + 1, FxID)
                        -- InsertToPost_Src = FX_Idx + offset+2
                        for i = 1, #Trk[TrkID].PostFX + 1, 1 do
                        r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: PostFX ' .. i, Trk[TrkID].PostFX[i] or '', true)
                        end
                    elseif SpaceIsBeforeRackMixer == 'SpcInBS' then
                        DropFXintoBS(FxID, FxGUID_Container, FX[FxGUID_Container].Sel_Band, FX_Idx, Dest + 1)
                    end
                    FX_Idx_OpenedPopup = nil
                    
                end
                r.ImGui_PopStyleColor(ctx)

                r.ImGui_EndDragDropTarget(ctx)
            end

            
        else
            
            Dvdr.Width[TblIdxForSpace] = 0
            Dvdr.Clr[ClrLbl] = 0x131313ff
            r.ImGui_SameLine(ctx, nil, 0)
        end


        
        
        r.ImGui_SameLine(ctx, nil, 0)
    end




    return WinW
end
