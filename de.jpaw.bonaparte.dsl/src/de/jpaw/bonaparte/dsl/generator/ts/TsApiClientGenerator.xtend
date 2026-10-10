package de.jpaw.bonaparte.dsl.generator.ts

import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition
import de.jpaw.bonaparte.dsl.bonScript.ClassReference
import java.util.ArrayList
import java.util.LinkedHashMap
import java.util.LinkedHashSet
import java.util.List
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess2

import static extension de.jpaw.bonaparte.dsl.generator.XUtil.*

class TsApiClientGenerator {
    def void doGenerate(Resource resource, IFileSystemAccess2 fsa) {
        if (!TsModuleResolver.isCurrentModule(resource))
            return

        val namingOverrides = TsNaming.loadOverrides
        val groups = new LinkedHashMap<String, List<TsRequestClassifier.RequestInfo>>
        for (source : resource.resourceSet.resources.filter[source | TsModuleResolver.isCurrentModule(source)]) {
            for (request : source.allContents.toIterable.filter(typeof(ClassDefinition))) {
                val info = TsRequestClassifier.classify(request)
                if (info !== null && info.pattern != TsRequestClassifier.Pattern.UNKNOWN) {
                    val apiClass = TsNaming.apiClassName(request.package.name, info.dtoName, request.name,
                        info.pattern, namingOverrides)
                    val groupKey = request.package.name + "|" + apiClass
                    var requests = groups.get(groupKey)
                    if (requests === null) {
                        requests = new ArrayList<TsRequestClassifier.RequestInfo>
                        groups.put(groupKey, requests)
                    }
                    requests.add(info)
                }
            }
        }

        for (group : groups.values) {
            val first = group.head.request
            val apiClass = TsNaming.apiClassName(first.package.name, group.head.dtoName,
                group.head.request.name, group.head.pattern, namingOverrides)
                fsa.generateFile(TsModuleResolver.outputFolder
                    + first.package.name.replace('.', '/') + "/" + apiClass + ".ts",
                writeApi(first.package.name, apiClass, group, namingOverrides))
        }
        if (TsModuleResolver.currentEntryPoint !== null)
            fsa.generateFile(TsModuleResolver.outputFolder + "api-index.ts",
                writeApiIndex(groups.values, namingOverrides))
    }

    def private static CharSequence writeApiIndex(Iterable<List<TsRequestClassifier.RequestInfo>> groups,
            java.util.Properties namingOverrides) {
        val exports = new LinkedHashSet<String>
        for (group : groups) {
            val first = group.head.request
            val apiClass = TsNaming.apiClassName(first.package.name, group.head.dtoName,
                first.name, group.head.pattern, namingOverrides)
            val modulePath = "./" + first.package.name.replace('.', '/') + "/" + apiClass
            exports.add("export { " + apiClass + " } from '" + modulePath + "';")
            for (info : group.filter[hasNamedExtras(it)])
                exports.add("export type { " + extrasTypeName(info) + " } from '" + modulePath + "';")
        }
        val out = new StringBuilder
        out.append(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT).append("\n\n")
        for (entry : exports)
            out.append(entry).append("\n")
        out
    }

    def private static CharSequence writeApi(String packageName, String apiClass,
            List<TsRequestClassifier.RequestInfo> requests, java.util.Properties namingOverrides) {
        val imports = new LinkedHashMap<String, EObject>
        for (info : requests) {
            imports.put(info.request.name, info.request)
            if (info.refName !== null) {
                val refType = findType(info.request, info.refName)
                if (refType !== null)
                    imports.put(refType.name, refType)
                for (subclass : refSubclasses(info))
                    imports.put(subclass.name, subclass)
            }
            if (info.responseRef !== null)
                collectTypeImports(info.responseRef, imports)
        }

        val out = new StringBuilder
        out.append(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT).append("\n\n")
        out.append("import { inject, Injectable } from '@angular/core';\n")
        out.append("import { Observable, map } from 'rxjs';\n")
        out.append("import { RpcClient } from '").append(rpcClientPath(packageName)).append("';\n")
        val unwraps = new LinkedHashSet<String>
        for (info : requests) {
            unwraps.add(unwrapName(info.responsePattern))
            if (isCrud(info.pattern))
                unwraps.add("unwrapVoid")
        }
        out.append("import { ").append(unwraps.join(", ")).append(" } from '")
            .append(rpcSupportPath(packageName)).append("';\n")
        for (info : requests.filter[responsePattern == TsRequestClassifier.ResponsePattern.LEAN_SEARCH]) {
            val description = findDescription(info.request, info.responseRef.classRef.package.name)
            if (description !== null) {
                imports.put(description.name, description)
            }
        }
        for (entry : imports.entrySet)
            out.append("import type { ").append(entry.key).append(" } from \"")
                .append(importPath(requests.head.request, packageName, entry.value, entry.key)).append("\";\n")
        for (info : requests.filter[hasNamedExtras(it)])
            out.append("\n").append(writeExtrasInterface(info))
        for (info : requests)
            out.append("\nconst ").append(info.request.name).append("PQON = \"")
                .append(info.request.package.name).append(".").append(info.request.name).append("\";\n")
        out.append("\n@Injectable({ providedIn: 'root' })\n")
        out.append("export class ").append(apiClass).append(" {\n")
        out.append("    private readonly rpc = inject(RpcClient);\n")
        val usedMethods = new LinkedHashSet<String>
        for (info : requests) {
            var methodName = TsNaming.methodName(info.request.name, info.pattern, info.dtoName, namingOverrides)
            if (isCrud(info.pattern))
                methodName = "execute" + (if (methodName.startsWith("create")) methodName.substring(6) else "")
            if (!usedMethods.add(methodName)) {
                methodName = methodName + capitalize(info.request.name)
                usedMethods.add(methodName)
            }
            val wireType = if (info.responseRef === null) "void" else renderType(info.responseRef)
            val resultType = resultType(info, wireType)
            val paramsType = requestParameterType(info)
            val paramsValue = if (hasPaging(info.pattern)) "{ ...params, offset: params.offset ?? 0 }" else "params"
            out.append("\n    ").append(methodName).append("(params: ").append(paramsType)
                .append("): Observable<").append(resultType).append("> {\n")
            out.append("        return this.rpc.call<").append(wireType).append(">(")
                .append(info.request.name).append("PQON, ").append(paramsValue).append(").pipe(map(")
                .append(unwrapExpression(info)).append("));\n")
            out.append("    }\n")
            if (isCrud(info.pattern))
                out.append(writeCrudMethods(info, methodName))
        }
        out.append("}\n")
        return out
    }

    def private static String requestParameterType(TsRequestClassifier.RequestInfo info) {
        val excluded = new ArrayList<String>
        excluded.add("'@PQON'")
        if (hasPaging(info.pattern))
            excluded.add("'offset'")
        if (hasNamedExtras(info))
            for (field : info.request.fields)
                excluded.add("'" + field.name + "'")
        var result = "Omit<" + info.request.name + ", " + excluded.join(" | ") + ">"
        if (hasPaging(info.pattern))
            result += " & { offset?: number }"
        if (hasNamedExtras(info))
            result += " & " + extrasTypeName(info)
        return result
    }

    def private static CharSequence writeExtrasInterface(TsRequestClassifier.RequestInfo info) {
        "export interface " + extrasTypeName(info) + " extends Pick<" + info.request.name + ", "
            + extraFieldNames(info) + "> {}\n"
    }

    def private static String extrasTypeName(TsRequestClassifier.RequestInfo info) {
        info.request.name + "Extras"
    }

    def private static String extraFieldNames(TsRequestClassifier.RequestInfo info) {
        info.request.fields.map["'" + name + "'"].join(" | ")
    }

    def private static boolean hasNamedExtras(TsRequestClassifier.RequestInfo info) {
        !info.request.fields.empty && (isCrud(info.pattern) || hasPaging(info.pattern))
    }

    def private static CharSequence writeCrudMethods(TsRequestClassifier.RequestInfo info, String executeName) {
        val dto = info.dtoName ?: "unknown"
        val ref = switch (info.pattern) {
            case CRUD_STRING: "string"
            default: refTypeUnion(info)
        }
        val suffix = if (executeName.startsWith("execute")) executeName.substring("execute".length) else ""
        val wireType = if (info.responseRef === null) "void" else renderType(info.responseRef)
        val excluded = new ArrayList<String>
        excluded.add("'@PQON'")
        excluded.add("'crud'")
        excluded.add("'data'")
        excluded.add("'onlyActive'")
        if (hasNamedExtras(info))
            for (field : info.request.fields)
                excluded.add("'" + field.name + "'")
        val extrasType = "Partial<Omit<" + info.request.name + ", " + excluded.join(" | ") + ">>"
            + (if (hasNamedExtras(info)) " & " + extrasTypeName(info) else "")
        val extrasDefault = if (info.request.fields.exists[cannotBeNull]) "" else " = {}"
        val methods = '''

            «"create" + suffix»(data: «dto», extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'C', onlyActive: false, data }).pipe(map(unwrapCrud<«dto»>));
            }

            «"read" + suffix»(key: «ref», extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'R', onlyActive: false, key }).pipe(map(unwrapCrud<«dto»>));
            }

            «"update" + suffix»(key: «ref», data: Partial<«dto»>, extras: «extrasType»«extrasDefault»): Observable<«dto»> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'U', onlyActive: false, key, data }).pipe(map(unwrapCrud<«dto»>));
            }

            «"delete" + suffix»(key: «ref», extras: «extrasType»«extrasDefault»): Observable<void> {
                return this.rpc.call<«wireType»>(«info.request.name»PQON, { ...extras, crud: 'D', onlyActive: false, key }).pipe(map(unwrapVoid));
            }
        '''
        return methods.toString.replaceAll("\\n(?=[ \\t]*\\S)", "\n    ")
    }

    def private static String refTypeUnion(TsRequestClassifier.RequestInfo info) {
        val refType = findType(info.request, info.refName)
        if (refType === null)
            return info.refName ?: "unknown"
        val types = new LinkedHashSet<String>
        types.add(refType.name)
        for (subclass : refSubclasses(info))
            types.add(subclass.name)
        return types.join(" | ")
    }

    def private static List<ClassDefinition> refSubclasses(TsRequestClassifier.RequestInfo info) {
        val refType = findType(info.request, info.refName)
        if (refType === null)
            return new ArrayList<ClassDefinition>
        val subclasses = new ArrayList<ClassDefinition>
        for (source : info.request.eResource.resourceSet.resources) {
            for (candidate : source.allContents.toIterable.filter(typeof(ClassDefinition))) {
                if (candidate !== refType && !candidate.isAbstract && extendsType(candidate, refType))
                    subclasses.add(candidate)
            }
        }
        return subclasses
    }

    def private static boolean extendsType(ClassDefinition candidate, ClassDefinition ancestor) {
        var ClassDefinition current = candidate
        while (current.extendsClass !== null && current.extendsClass.classRef !== null) {
            current = current.extendsClass.classRef
            if (current === ancestor)
                return true
        }
        return false
    }

    def private static void collectTypeImports(ClassReference ref, Map<String, EObject> imports) {
        if (ref.classRef !== null)
            imports.put(ref.classRef.name, ref.classRef)
        for (argument : ref.classRefGenericParms)
            collectTypeImports(argument, imports)
    }

    def private static String renderType(ClassReference ref) {
        if (ref.plainObject)
            return "BonaPortable"
        if (ref.classRef !== null) {
            val arguments = ref.classRefGenericParms.map[renderType(it)]
            return ref.classRef.name + (if (arguments.empty) "" else "<" + arguments.join(", ") + ">")
        }
        if (ref.genericsParameterRef !== null)
            return ref.genericsParameterRef.name
        return "unknown"
    }

    def private static String resultType(TsRequestClassifier.RequestInfo info, String wireType) {
        switch (info.responsePattern) {
            case SEARCH: if (info.dtoName === null) "unknown[]" else info.dtoName + "[]"
            case CRUD: if (info.dtoName === null) "unknown" else info.dtoName
            case RESOLVE: "number"
            case RESOLVE_MANY: "number[]"
            case LEAN_SEARCH: "Description[]"
            case SERVICE: "Omit<" + wireType + ", 'returnCode'>"
            case VOID: "void"
        }
    }

    def private static String unwrapExpression(TsRequestClassifier.RequestInfo info) {
        switch (info.responsePattern) {
            case SEARCH: "unwrapSearch<" + (info.dtoName ?: "unknown") + ">"
            case CRUD: "unwrapCrud<" + (info.dtoName ?: "unknown") + ">"
            case RESOLVE: "unwrapResolve"
            case RESOLVE_MANY: "unwrapResolveMany"
            case LEAN_SEARCH: "unwrapLean"
            case SERVICE: "unwrapService<" + renderType(info.responseRef) + ">"
            case VOID: "unwrapVoid"
        }
    }

    def private static boolean isCrud(TsRequestClassifier.Pattern pattern) {
        pattern == TsRequestClassifier.Pattern.CRUD_SURROGATE
                || pattern == TsRequestClassifier.Pattern.CRUD_STRING
                || pattern == TsRequestClassifier.Pattern.CRUD_COMPOSITE
                || pattern == TsRequestClassifier.Pattern.CRUD_MODULE
    }

    def private static boolean hasPaging(TsRequestClassifier.Pattern pattern) {
        pattern == TsRequestClassifier.Pattern.SEARCH
                || pattern == TsRequestClassifier.Pattern.LEAN_SEARCH
                || pattern == TsRequestClassifier.Pattern.RESOLVE_MANY
    }

    def private static ClassDefinition findDescription(ClassDefinition request, String packageName) {
        for (resource : request.eResource.resourceSet.resources)
            for (candidate : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
                if (candidate.name == "Description" && candidate.package.name == packageName)
                    return candidate
        return null
    }

    def private static ClassDefinition findType(ClassDefinition request, String typeName) {
        for (resource : request.eResource.resourceSet.resources)
            for (candidate : resource.allContents.toIterable.filter(typeof(ClassDefinition)))
                if (candidate.name == typeName)
                    return candidate
        return null
    }

    def private static String unwrapName(TsRequestClassifier.ResponsePattern pattern) {
        switch (pattern) {
            case SEARCH: "unwrapSearch"
            case CRUD: "unwrapCrud"
            case RESOLVE: "unwrapResolve"
            case RESOLVE_MANY: "unwrapResolveMany"
            case LEAN_SEARCH: "unwrapLean"
            case SERVICE: "unwrapService"
            case VOID: "unwrapVoid"
        }
    }

    def private static String importPath(ClassDefinition from, String fromPackage, EObject target, String name) {
        val crossModule = if (from.eResource !== null && target.eResource !== null)
            TsModuleResolver.crossModuleImport(from, target)
            else null
        if (crossModule !== null)
            return crossModule
        val fromParts = fromPackage.split("\\.")
        val toParts = target.package.name.split("\\.")
        var common = 0
        while (common < fromParts.length && common < toParts.length && fromParts.get(common) == toParts.get(common))
            common++
        val path = new StringBuilder
        if (common == fromParts.length)
            path.append("./")
        else
            for (i : common ..< fromParts.length)
                path.append("../")
        for (i : common ..< toParts.length)
            path.append(toParts.get(i)).append("/")
        path.append(name)
        return path.toString
    }

    def private static String rpcClientPath(String packageName) {
        val depth = packageName.split("\\.").length
        val path = new StringBuilder
        for (i : 0 ..< depth)
            path.append("../")
        if (TsModuleResolver.currentEntryPoint !== null)
            path.append("../")
        path.append("rpc-core/rpc-client")
        return path.toString
    }

    def private static String rpcSupportPath(String packageName) {
        rpcClientPath(packageName).replace("rpc-client", "unwrap")
    }

    def private static String capitalize(String name) {
        if (name.length == 0) name else name.substring(0, 1).toUpperCase + name.substring(1)
    }
}