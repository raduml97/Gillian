module Types = struct
  type conf = { filename : string }

  type state = { out_channel : out_channel; formatter : Format.formatter }
end

include Reporter.Make (struct
  include Types

  let enabled = true

  let conf = { filename = "out.log" }

  let initialize { filename; _ } =
    let out_channel = open_out filename in
    let formatter = Format.formatter_of_out_channel out_channel in
    { out_channel; formatter }

  let wrap_up { out_channel; _ } = close_out out_channel
end)

let get_formatter () =
  let state = get_state () in
  state.formatter

class t =
  object (self)
    method log (report : Report.t) =
      if enabled () then
        match report.content with
        | Debug msgf  ->
            Report.PackedPP.pf self#formatter msgf;
            Format.fprintf self#formatter "@,@?"
        | Phase phase ->
            Format.fprintf self#formatter "*** Phase %s ***@,@?"
            @@ Report.string_of_phase phase

    method private formatter = get_formatter ()

    method wrap_up = wrap_up ()
  end
