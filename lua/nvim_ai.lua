local Export = {}

function Export.test()
  print("ok")
end

-- call nvim_ai#test()
function Export.windows_init()
  -- 请注意：这是一个尝试包裹代码的示例，具体语法细节可能有所不同，请根据实际需要进行调整
  local success, result = pcall(function ()
    local Layout = require("nui.layout")
    local Popup = require("nui.popup")
    return {
      Layout = Layout,
      Popup = Popup
    }
  end)
  if not success then
    print("nui.nvim is not installed, please install it via `use 'MunifTanjim/nui.nvim'`")
    return
  end

  local Layout = result.Layout
  local Popup = result.Popup

  local popup_one, popup_two = Popup({
    enter = true,
    border = "single",
  }), Popup({
    border = "double",
  })

  local layout = Layout(
  {
    position = "50%",
    size = {
      width = 80,
      height = "60%",
    },
  },
  Layout.Box({
    Layout.Box(popup_one, { size = "40%" }),
    Layout.Box(popup_two, { size = "60%" }),
  }, { dir = "row" })
  )

  local current_dir = "row"

  popup_one:map("n", "r", function()
    if current_dir == "col" then
      layout:update(Layout.Box({
        Layout.Box(popup_one, { size = "40%" }),
        Layout.Box(popup_two, { size = "60%" }),
      }, { dir = "row" }))

      current_dir = "row"
    else
      layout:update(Layout.Box({
        Layout.Box(popup_two, { size = "60%" }),
        Layout.Box(popup_one, { size = "40%" }),
      }, { dir = "col" }))

      current_dir = "col"
    end
  end, {})

  layout:mount()

end

return Export 
