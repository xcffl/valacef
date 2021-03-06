namespace CefGtk.Utils {

/**
 * Create new CEF process message.
 * 
 * @param name         Message name.
 * @param parameters    Message parameters.
 * @return New CEF process message.
 */
public Cef.ProcessMessage? create_process_message(string name, Variant?[] parameters) {
    Cef.String msg_name = {};
    Cef.set_string(&msg_name, name);
    var msg = Cef.process_message_create(&msg_name);
    var args = msg.get_argument_list();
    set_list_from_variant(args, parameters);
    return msg;
}


/**
 * Unpack variant.
 * 
 *  @param variant    Value to unpack.
 * @return Unpacked variant, Variant and maybe type are replaced by child variants.
 */
public Variant? unpack_variant(Variant? variant) {
    if (variant == null) {
        return null;
    } else if (variant.is_of_type(VariantType.VARIANT)) {
        return unpack_variant(variant.get_variant());
    } else if (variant.get_type().is_subtype_of(VariantType.MAYBE)) {
        Variant? maybe_variant = null;
        variant.get("m*", &maybe_variant);
        return unpack_variant(maybe_variant);
    }
    return variant;
}


/**
 * Populate CEF list with Variant values.
 * 
 * @param list      CEF list to populate.
 * @param values    Variant values.
 */
public void set_list_from_variant(Cef.ListValue list, Variant?[] values, int offset=0) {
    list.set_size(values.length + offset);
    for (var i = 0; i < values.length; i++) {
        var index = offset + i;
        var variant = unpack_variant(values[i]);
        if (variant == null) {
            list.set_null(index);
        } else {
            var type = variant.get_type();
            var object_type = new VariantType("a{s*}");
            if (type.is_subtype_of(object_type)) {
                critical("Object type is not supported (%d).", index);
                list.set_null(index);
            } else if (variant.is_of_type(VariantType.STRING)) {
                Cef.String cef_string = {};
                Cef.set_string(&cef_string, variant.get_string());
                list.set_string(index, &cef_string);
            } else if (variant.is_of_type(VariantType.BOOLEAN)) {
                list.set_bool(index, variant.get_boolean() ? 1 : 0);
            } else if (variant.is_of_type(VariantType.DOUBLE)) {
                list.set_double(index, variant.get_double());
            } else if (variant.is_of_type(VariantType.INT32)) {
                list.set_int(index, (int) variant.get_int32());
            } else if (variant.is_of_type(VariantType.UINT32)) {
                list.set_int(index, (int) variant.get_uint32());
            } else if (variant.is_of_type(VariantType.INT64)) {
                list.set_int(index, (int) variant.get_int64());
            } else if (variant.is_of_type(VariantType.UINT64)) {
                list.set_int(index, (int) variant.get_uint64());
            } else {
                critical("Type %s not supported at index %d", type.dup_string(), index);
                list.set_null(index);
            }
        }
    }
}

/**
 * Convert CEF list to Variant values.
 * 
 * @param list    CEF list to convert.
 * @return Variant values.
 */
public Variant?[] convert_list_to_variant(Cef.ListValue list) {
    var size = list.get_size();
    if (size == 0) {
        return {};
    }
    var result = new Variant?[size];
    for (var index = 0; index < size; index++) {
        var type = list.get_type(index);
        switch (type) {
        case Cef.ValueType.NULL:
            result[index] = null;
            break;
        case Cef.ValueType.BOOL:
            result[index] = new Variant.boolean(list.get_bool(index) > 0);
            break;
        case Cef.ValueType.INT:
            result[index] = new Variant.int64(list.get_int(index));
            break;
        case Cef.ValueType.DOUBLE:
            result[index] = new Variant.double(list.get_double(index));
            break;
        case Cef.ValueType.STRING:
            result[index] = new Variant.string(list.get_string(index));
            break;
        case Cef.ValueType.INVALID:
        case Cef.ValueType.BINARY:
        case Cef.ValueType.DICTIONARY:
        case Cef.ValueType.LIST:
        default:
            critical("Unsupported type %s at index %d.", type.to_string(), index);
            result[index] = null;
            break;
        }
    }
    return result;
}

} // CefGtk.Utils
