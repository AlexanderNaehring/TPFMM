local descEN = [[DescriptionEN
MULTI LINE]]

local descFR = [[DESC FR]]

local descZH = [[你好 (DESC ZH)]]

function data()
    return {
        en = {
            ["name"] = "Mod Name EN",
            ["desc"] = descEN
        },
        fr = {
            ["name"] = "Mod name FR",
            ["desc"] = descFR
        },
        zh_CN = {
            ["name"] = "你好 (MOD ZH)",
            ["desc"] = descZH
        }
    }
end
