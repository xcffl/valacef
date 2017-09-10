from typing import Set

from CppHeaderParser import CppHeader

from valacefgen.types import Repository, EnumValue, Enum, Struct, Typedef, StructMember
from valacefgen.utils import find_prefix, lstrip, rstrip, camel_case
from valacefgen import utils


class Naming:
    def __init__(self, strip_prefix: str):
        self.strip_prefix = strip_prefix

    def enum(self, name: str) -> str:
        return camel_case(rstrip(lstrip(name, self.strip_prefix.lower() + "_"), '_t'))

    def struct(self, name: str) -> str:
        return camel_case(rstrip(lstrip(name, self.strip_prefix.lower() + "_"), '_t'))

    def typedef(self, name: str) -> str:
        return camel_case(rstrip(lstrip(name, self.strip_prefix.lower() + "_"), '_t'))

    def camel_case(self, name: str) -> str:
        return camel_case(rstrip(lstrip(name, self.strip_prefix.lower() + "_"), '_t'))

    def delegate(self, prefix: str, name: str) -> str:
        return self.camel_case(prefix) + self.camel_case(name)


class Parser:
    def __init__(self, naming: Naming, repo: Repository, ignore: Set[str]):
        self.ignore = ignore
        self.naming = naming
        self.repo = repo

    def parse_header(self, path: str, c_include_path: str):
        with open(path) as f:
            data = f.read().replace('CEF_EXPORT', '').replace('CEF_CALLBACK', '')
        header = CppHeader(data, 'string')
        self.parse_typedefs(c_include_path, header.typedefs)
        self.parse_enums(c_include_path, header.enums)
        self.parse_structs(c_include_path, header.classes)

    def parse_typedefs(self, c_include_path: str, typedefs):
        for alias, c_type in typedefs.items():
            if alias not in self.ignore:
                self.parse_typedef(c_include_path, alias, c_type)

    def parse_typedef(self, c_include_path: str, alias: str, c_type: str):
        bare_c_type = utils.bare_c_type(c_type)
        self.repo.add_typedef(Typedef(alias, self.naming.typedef(alias), bare_c_type, c_include_path))

    def parse_enums(self, c_include_path: str, enums):
        for enum in enums:
            if enum['typedef']:
                name = enum['name']
                values = [v['name'] for v in enum['values']]
                n_prefix = len(find_prefix(values))
                values = [EnumValue(v, v[n_prefix:]) for v in values]
                self.repo.add_enum(Enum(name, self.naming.enum(name), c_include_path, values))
            else:
                raise NotImplementedError

    def parse_structs(self, c_include_path: str, structs):
        for name, klass in structs.items():
            self.parse_struct(c_include_path, name, klass)

    def parse_struct(self, c_include_path: str, struct_name: str, klass):
        properties = klass['properties']
        if klass['declaration_method'] == 'class':
            raise NotImplementedError(struct_name)
        struct_members = []
        for member in properties["public"]:
            c_name = member["name"]
            c_type = member["type"]
            if utils.is_func_pointer(c_type):
                vala_type = self.naming.delegate(struct_name, c_name)
                struct_members.append(StructMember(vala_type, c_name, c_name))
            else:
                struct_members.append(StructMember(c_type, c_name, c_name))
        self.repo.add_struct(Struct(struct_name, self.naming.struct(struct_name), c_include_path, struct_members))
