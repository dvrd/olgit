package failz

import "../ansi"
import "core:compress"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

catch :: proc(err: Error, msg: string = "", should_exit := true, location := #caller_location) {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	file_path := ansi.bold(location.file_path)
	defer delete(file_path)

	procedure := purple(location.procedure)
	defer delete(procedure)

	fmt.sbprintfln(
		&sb,
		"%s %s: %s at %d:%d",
		ERROR,
		file_path,
		procedure,
		location.line,
		location.column,
	)

	if len(msg) != 0 {fmt.sbprintln(&sb, MESSAGE, msg)}

	#partial switch e in err {
	case AllocError:
		if e == nil {return}
		fmt.sbprint(&sb, MESSAGE, e)
		fmt.eprintln(strings.to_string(sb))
	case UnmarshalError:
		if e == nil {return}
		switch ue in e {
		case json.Error, json.Unmarshal_Data_Error, json.Unsupported_Type_Error:
			fmt.sbprint(&sb, MESSAGE, ue)
		}
		fmt.eprintln(strings.to_string(sb))
	case CompressionError:
		if e == nil {return}
		#partial switch ce in e {
		case compress.General_Error, compress.Deflate_Error, compress.ZLIB_Error, compress.GZIP_Error, compress.ZIP_Error, AllocError:
			fmt.sbprint(&sb, MESSAGE, ce)
		}
		fmt.eprintln(strings.to_string(sb))
	case IOError:
		if e == nil {return}
		fmt.sbprint(&sb, MESSAGE, e)
		fmt.eprintln(strings.to_string(sb))
	case AppError:
		fmt.sbprint(&sb, MESSAGE, purple(fmt.tprintf("[%v]", e.kind)), e.msg)
		fmt.eprintln(strings.to_string(sb))
	case SystemError:
		fmt.sbprint(&sb, MESSAGE, purple(fmt.tprintf("[%v]", e.kind)), e.msg)
		fmt.eprintln(strings.to_string(sb))
	case Errno:
		if e == .ERROR_NONE {return}
		fmt.sbprint(&sb, MESSAGE, os.get_last_error_string())
		fmt.eprintln(strings.to_string(sb))
	case bool:
		if !e {return}
		fmt.eprintln(strings.to_string(sb))
	}

	if err != nil && should_exit {os.exit(1)}
}
