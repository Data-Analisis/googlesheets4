sheets_write <- function(data,
                         ss,
                         sheet = NULL,
                         skip = 0,
                         na = "") {
  # https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/request#updatecellsrequest
  ssid <- as_sheets_id(ss)
  check_sheet(sheet)
  check_non_negative_integer(skip)

  # retrieve spreadsheet metadata ----------------------------------------------
  x <- sheets_get(ssid)
  message_glue("Writing to {sq(x$name)}")

  # capture sheet id and start row ---------------------------------------------
  # `start` (or `range`) must be sent, even if `skip = 0`
  # we always send a sheet id
  # if we don't, the default is 0
  # but there's no guarantee that there is such a sheet id
  # it's more trouble to check for that than to just send a sheet id
  s <- lookup_sheet(sheet, sheets_df = x$sheets)
  message_glue("Writing to sheet {dq(s$name)}")
  start <- new("GridCoordinate", sheetId = s$id)
  if (skip > 0) {
    start <- patch(start, rowIndex = skip)
    message_glue("Starting at row {skip + 1}")
  }

  # pack the data --------------------------------------------------------------
  request_values <- new(
    "UpdateCellsRequest",
    start = start,
    rows = as_RowData(data), # an array of instances of RowData
    fields = "userEnteredValue"
  )

  req <- request_generate(
    "sheets.spreadsheets.batchUpdate",
    params = list(
      spreadsheetId = ssid,
      requests = list(
        # clear existing data and formatting
        list(repeatCell = style_clear_sheet(s$id)),
        # write data
        list(updateCells = request_values),
        # configure header row
        list(updateSheetProperties =
               style_frozen_rows(n = skip + 1, sheetId = s$id)),
        list(repeatCell = style_header_row(row = skip + 1, sheetId = s$id))
      )
    )
  )
  resp_raw <- request_make(req)
  gargle::response_process(resp_raw)

  sheets_get(ssid)
}

# docs on Sheets NA
# https://support.google.com/docs/answer/3093359?hl=en
# #N/A