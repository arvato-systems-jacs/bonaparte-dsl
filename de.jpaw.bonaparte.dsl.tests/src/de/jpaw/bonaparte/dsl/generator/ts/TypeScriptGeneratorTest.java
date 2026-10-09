package de.jpaw.bonaparte.dsl.generator.ts;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Map;
import java.util.Properties;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Injector;

import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup;
import de.jpaw.bonaparte.dsl.bonScript.ClassDefinition;
import de.jpaw.bonaparte.dsl.generator.DataTypeExtension;

/** Parses small .bon sources and checks the TypeScript produced by the generator. */
public class TypeScriptGeneratorTest {
    private static final String ROOT = "DEFAULT_OUTPUT" + TypeScriptBonScriptGeneratorMain.GENERATED_TS_SUBFOLDER;

    private static Injector injector;

    private static final String BON_SOURCE = String.join("\n",
        "package com.acme.base {",
        "    enum SortOrder { ASC, DESC }",
        "    enum Mode { A = \"a\", B = \"b\" }",
        "    xenum TimeUnit is Mode : 1;",
        "    enumset<int> SortOrderSet is SortOrder;",
        "    xenumset TimeUnitSet is TimeUnit;",
        "    class Base {",
        "        required long objectRef;",
        "    }",
        "    @Deprecated",
        "    class Legacy {",
        "        required long id;",
        "    }",
        "}",
        "package com.acme.auth {",
        "    type Name is unicode(30);",
        "    class Child<T> extends com.acme.base.Base {",
        "        required Name name;",
        "        optional Unicode(20) nickname;",
        "        required boolean active;",
        "        optional Integer age;",
        "        optional Instant created;",
        "        required enum com.acme.base.SortOrder order;",
        "        optional XEnum com.acme.base.TimeUnit unit;",
        "        required unicode(10) required List<5> tags;",
        "        optional Unicode(10) Map<String> labels;",
        "        optional (com.acme.base.Base) other;",
        "        optional (!T) payload;",
        "        optional Json extra;",
        "        required enumset com.acme.base.SortOrderSet modes;",
        "        required xenumset com.acme.base.TimeUnitSet(10) units;",
        "        optional Object blob;",
        "        @Deprecated",
        "        optional Integer oldAge;",
        "    }",
        "}",
        "");

    private static final String CLASSIFIER_SOURCE = String.join("\n",
        "package com.acme.api {",
        "    class ServiceResponse {}",
        "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<DATA, TRACKING> {}",
        "    class LeanSearchResponse extends ServiceResponse {}",
        "    class RefResolverResponse extends ServiceResponse {}",
        "    class MassResolverResponse extends ServiceResponse {}",
        "    class CrudAnyKeyResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class CrudSurrogateResponse<DATA, TRACKING> extends CrudAnyKeyResponse<DATA, TRACKING> {}",
        "    class SearchRequest<DATA, TRACKING> return ReadAllResponse<!DATA, !TRACKING> {}",
        "    class LeanSearchRequest return LeanSearchResponse {}",
        "    class RefResolverRequest<REF> return RefResolverResponse {}",
        "    class MassResolverRequest return MassResolverResponse {}",
        "    abstract class AbstractSearch<T> extends SearchRequest<!T, Audit> {}",
        "    class DirectSearchRequest extends SearchRequest<ProductDTO, Audit> {}",
        "    class InheritedSearchRequest extends AbstractSearch<ProductDTO> {}",
        "    class CustomSearchResponse extends ServiceResponse {}",
        "    class SearchResponseWithTypes<DATA, TRACKING> {}",
        "    class BaseReturnedSearch extends SearchRequest<ProductDTO, Audit> return SearchResponseWithTypes<ProductDTO, Audit> {}",
        "    class InheritedReturnedSearch extends BaseReturnedSearch {}",
        "    class OverrideReturnedSearch extends BaseReturnedSearch return CustomSearchResponse {}",
        "    class GenericResponseBase<DATA, TRACKING> extends SearchRequest<DATA, TRACKING> return SearchResponseWithTypes<!DATA, !TRACKING> {}",
        "    class GenericReturnedSearch extends GenericResponseBase<ProductDTO, Audit> {}",
        "    class DirectLeanSearchRequest extends LeanSearchRequest {}",
        "    class DirectResolverRequest extends RefResolverRequest<ProductRef> {}",
        "    class DirectMassResolverRequest extends MassResolverRequest {}",
        "    class RequestParameters return ServiceResponse {}",
        "    class SpecialRequest extends RequestParameters {}",
        "    abstract class AbstractRequest extends RequestParameters {}",
        "    class ProductDTO {}",
        "    class Audit {}",
        "    class ProductRef {}",
        "    class Description {}",
        "}",
        "");

    private static final String API_SOURCE = String.join("\n",
        "package com.acme.api {",
        "    class ServiceResponse {}",
        "    class SearchResponse<DATA, TRACKING> extends ServiceResponse {}",
        "    class ReadAllResponse<DATA, TRACKING> extends SearchResponse<DATA, TRACKING> {}",
        "    class SearchCriteria { required int limit; required int offset; }",
        "    class SearchRequest<DATA, TRACKING> extends SearchCriteria return ReadAllResponse<!DATA, !TRACKING> {}",
        "    class ProductDTO {}",
        "    class FullTracking {}",
        "    class ProductSearchRequest extends SearchRequest<ProductDTO, FullTracking> {}",
        "    class ProductSearchExtendedRequest extends ProductSearchRequest {}",
        "    class LeanSearchResponse extends ServiceResponse {}",
        "    class Description {}",
        "    class LeanSearchRequest extends SearchCriteria return LeanSearchResponse {}",
        "    class PriceListLeanSearchRequest extends LeanSearchRequest {}",
        "    class RefResolverResponse extends ServiceResponse {}",
        "    class RefResolverRequest<REF> return RefResolverResponse {}",
        "    class ProductRef {}",
        "    class ProductResolverRequest extends RefResolverRequest<ProductRef> {}",
        "    class MassResolverResponse extends ServiceResponse {}",
        "    class MassResolverRequest extends SearchCriteria return MassResolverResponse {}",
        "    class ProductMassResolverRequest extends MassResolverRequest {}",
        "}",
        "");

    @BeforeClass
    public static void setup() {
        injector = new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
    }

    private Map<String, CharSequence> generate(String source) throws Exception {
        XtextResource res = parse(source);
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        try {
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class).doGenerate(res, fsa, new GeneratorContext());
        } finally {
            DataTypeExtension.clear();
        }
        return fsa.getTextFiles();
    }

    private Map<String, CharSequence> generateApis(String source) throws Exception {
        XtextResource res = parse(source);
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        injector.getInstance(TsApiClientGenerator.class).doGenerate(res, fsa);
        return fsa.getTextFiles();
    }

    private XtextResource parse(String source) throws Exception {
        XtextResourceSet rs = injector.getInstance(XtextResourceSet.class);
        XtextResource res = (XtextResource) rs.createResource(URI.createURI("dummy:/test.bon"));
        res.load(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)), Collections.emptyMap());
        assertTrue("parse errors: " + res.getErrors(), res.getErrors().isEmpty());
        return res;
    }

    private static ClassDefinition findClass(XtextResource resource, String name) {
        TreeIterator<EObject> contents = resource.getAllContents();
        while (contents.hasNext()) {
            EObject object = contents.next();
            if (object instanceof ClassDefinition clazz && name.equals(clazz.getName()))
                return clazz;
        }
        throw new IllegalArgumentException("Unknown BON class: " + name);
    }

    private static String norm(CharSequence s) {
        assertNotNull(s);
        return s.toString().replace("\r", "");
    }

    @Test
    public void generatesOneFilePerTypeInPackageFolders() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/SortOrder", "base/Mode", "base/TimeUnit", "base/Base", "auth/Child" })
            assertTrue("missing " + f + " in " + files.keySet(), files.containsKey(ROOT + "com/acme/" + f + ".ts"));
    }

    @Test
    public void enumsAndXEnums() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        // plain enums are serialized as numeric ordinals
        String plain = norm(files.get(ROOT + "com/acme/base/SortOrder.ts"));
        assertTrue(plain, plain.contains("export const SortOrder = {"));
        assertTrue(plain, plain.contains("ASC: 0,"));
        assertTrue(plain, plain.contains("DESC: 1"));
        assertTrue(plain, plain.contains("export type SortOrder = (typeof SortOrder)[keyof typeof SortOrder];"));
        // alphanumeric enums use the token as value
        String alpha = norm(files.get(ROOT + "com/acme/base/Mode.ts"));
        assertTrue(alpha, alpha.contains("A: \"a\","));
        assertTrue(alpha, alpha.contains("B: \"b\""));
        assertTrue(norm(files.get(ROOT + "com/acme/base/TimeUnit.ts")).contains("export type TimeUnit = string;"));
    }

    @Test
    public void interfaceWithInheritanceAndImports() throws Exception {
        String base = norm(generate(BON_SOURCE).get(ROOT + "com/acme/base/Base.ts"));
        assertTrue(base, base.contains("export const BasePQON = \"com.acme.base.Base\" as const;"));
        assertTrue(base, base.contains("export interface Base {"));
        assertTrue(base, base.contains("objectRef: number;"));

        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("import type { Base } from \"../base/Base\";"));
        assertTrue(child, child.contains("import type { SortOrder } from \"../base/SortOrder\";"));
        assertTrue(child, child.contains("import type { TimeUnit } from \"../base/TimeUnit\";"));
        assertTrue(child, child.contains("export const ChildPQON = \"com.acme.auth.Child\" as const;"));
        assertTrue(child, child.contains("export interface Child<T = unknown> extends Omit<Base, '@PQON'> {"));
        assertTrue(child, child.contains("'@PQON': typeof ChildPQON;"));
    }

    @Test
    public void fieldTypesAndOptionality() throws Exception {
        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertField(child, "name: string;");                     // typedef resolved, required
        assertField(child, "nickname?: string | null;");         // optional scalar
        assertField(child, "active: boolean;");
        assertField(child, "age?: number | null;");
        assertField(child, "created?: number | null;");          // instants are epoch seconds
        assertField(child, "order: SortOrder;");
        assertField(child, "unit?: TimeUnit | null;");
        assertField(child, "tags: (string | null)[];");          // required list, elements may be null
        assertField(child, "labels?: Record<string, string>;");  // map
        assertField(child, "other?: Base | null;");
        assertField(child, "payload?: T | null;");               // generics parameter
        assertField(child, "extra?: Record<string, unknown> | null;");
        assertField(child, "modes: number;");                    // numeric enumset -> integer bitmap (required by spec)
        assertField(child, "units: string;");                    // xenumset -> string (required by spec)
        assertField(child, "blob?: BonaPortable | null;");       // plain Object
        assertField(child, "oldAge?: number | null;");           // deprecated field still generated
    }

    @Test
    public void everyObjectHasPqonField() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        for (String f : new String[] { "base/Base", "base/Legacy", "auth/Child" })
            assertTrue(f, norm(files.get(ROOT + "com/acme/" + f + ".ts")).contains("'@PQON': typeof"));
    }

    @Test
    public void deprecatedTypesAndFieldsAreMarked() throws Exception {
        Map<String, CharSequence> files = generate(BON_SOURCE);
        String legacy = norm(files.get(ROOT + "com/acme/base/Legacy.ts"));
        assertTrue(legacy, legacy.contains("/** @deprecated */"));
        assertTrue(legacy, legacy.contains("export interface Legacy {"));
        String child = norm(files.get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("/** @deprecated */"));
        assertTrue(child, child.contains("oldAge?: number | null;"));
    }

    private static void assertField(String content, String line) {
        assertTrue("expected line '" + line + "' in:\n" + content, content.lines().anyMatch(l -> l.trim().equals(line)));
    }

    @Test
    public void headerMarksFileAsGenerated() throws Exception {
        String content = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertEquals(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT, content.lines().findFirst().orElse(""));
    }

    @Test
    public void moduleMapResolvesNpmEntryPoint() {
        Properties modules = new Properties();
        modules.setProperty("t9t-base-api", "@arvato-systems-jacs/t9t-api,base");
        assertEquals("@arvato-systems-jacs/t9t-api/base",
            TsModuleResolver.importSpecifier("t9t-base-api", modules));
    }

    @Test
    public void typeGuardMatchesTheLiteralPqon() {
        assertEquals("export function isChild(value: unknown): value is Child {\n"
                + "    return typeof value === \"object\" && value !== null && (value as Record<string, unknown>)[\"@PQON\"] === \"com.acme.auth.Child\";\n"
                + "}\n", TsModuleResolver.typeGuard("Child", "com.acme.auth.Child"));
    }

    @Test
    public void classifiesDirectAndInheritedSearchRequests() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        TsRequestClassifier.RequestInfo direct = TsRequestClassifier.classify(
                findClass(resource, "DirectSearchRequest"));
        assertEquals(TsRequestClassifier.Pattern.SEARCH, direct.pattern);
        assertEquals("ProductDTO", direct.dtoName);
        assertEquals("Audit", direct.trackingName);
        assertEquals(TsRequestClassifier.ResponsePattern.SEARCH, direct.responsePattern);

        TsRequestClassifier.RequestInfo inherited = TsRequestClassifier.classify(
                findClass(resource, "InheritedSearchRequest"));
        assertEquals(TsRequestClassifier.Pattern.SEARCH, inherited.pattern);
        assertEquals("ProductDTO", inherited.dtoName);
        assertEquals("Audit", inherited.trackingName);
    }

    @Test
    public void skipsAbstractRequestClasses() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        assertNull(TsRequestClassifier.classify(findClass(resource, "AbstractRequest")));
    }

    @Test
    public void classifiesOtherRequestFamilies() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        assertEquals(TsRequestClassifier.Pattern.LEAN_SEARCH,
                TsRequestClassifier.classify(findClass(resource, "DirectLeanSearchRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.RESOLVE_MANY,
                TsRequestClassifier.classify(findClass(resource, "DirectMassResolverRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.RESOLVE,
            TsRequestClassifier.classify(findClass(resource, "DirectResolverRequest")).pattern);
        assertEquals(TsRequestClassifier.Pattern.SPECIAL,
                TsRequestClassifier.classify(findClass(resource, "SpecialRequest")).pattern);
    }

    @Test
    public void resolvesNearestInheritedResponseDeclaration() throws Exception {
        XtextResource resource = parse(CLASSIFIER_SOURCE);
        TsRequestClassifier.RequestInfo inherited = TsRequestClassifier.classify(
                findClass(resource, "InheritedReturnedSearch"));
        assertEquals("SearchResponseWithTypes", inherited.responseRef.getClassRef().getName());

        TsRequestClassifier.RequestInfo overridden = TsRequestClassifier.classify(
                findClass(resource, "OverrideReturnedSearch"));
        assertEquals("CustomSearchResponse", overridden.responseRef.getClassRef().getName());
        assertEquals(TsRequestClassifier.Pattern.SPECIAL, overridden.pattern);

        TsRequestClassifier.RequestInfo generic = TsRequestClassifier.classify(
            findClass(resource, "GenericReturnedSearch"));
        assertEquals("ProductDTO", generic.responseRef.getClassRefGenericParms().get(0).getClassRef().getName());
        assertEquals("Audit", generic.responseRef.getClassRefGenericParms().get(1).getClassRef().getName());
    }

    @Test
    public void derivesApiAndVariantMethodNames() {
        assertEquals("ProductApi", TsNaming.apiClassName("com.acme.request", "ProductDTO"));
        assertEquals("A28cartApi", TsNaming.apiClassName("t9t.a28cart.request", null));
        assertEquals("createViaApi", TsNaming.methodName("ProductCrudViaApiRequest",
                TsRequestClassifier.Pattern.CRUD_SURROGATE, "ProductDTO"));
        assertEquals("searchAndEnrichment", TsNaming.methodName("LoyaltyCardSearchAndEnrichmentRequest",
                TsRequestClassifier.Pattern.SEARCH, "LoyaltyCardDTO"));
        assertEquals("searchExtended", TsNaming.methodName("SalesOrderExtendedSearchRequest",
            TsRequestClassifier.Pattern.SEARCH, "SalesOrderDTO"));
        assertEquals("reserveCoupon", TsNaming.methodName("ReserveCouponRequest",
                TsRequestClassifier.Pattern.SPECIAL, null));
        assertEquals("PriceListApi", TsNaming.apiClassName("t9t.pricing.request", null,
            "PriceListLeanSearchRequest", TsRequestClassifier.Pattern.LEAN_SEARCH));
        assertEquals("leanSearch", TsNaming.methodName("PriceListLeanSearchRequest",
            TsRequestClassifier.Pattern.LEAN_SEARCH, null));
    }

    @Test
    public void generatesGroupedTypedSearchApi() throws Exception {
        Map<String, CharSequence> files = generateApis(API_SOURCE);
        String api = norm(files.get(ROOT + "com/acme/api/ProductApi.ts"));
        assertTrue(api, api.contains("export class ProductApi {"));
        assertTrue(api, api.contains("search(params: Omit<ProductSearchRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<ProductDTO[]>"));
        assertTrue(api, api.contains("searchExtended(params: Omit<ProductSearchExtendedRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<ProductDTO[]>"));
        assertTrue(api, api.contains(".pipe(map(unwrapSearch<ProductDTO>))"));
        assertTrue(api, api.contains("const ProductSearchRequestPQON = \"com.acme.api.ProductSearchRequest\";"));
        assertTrue(api, api.contains("ProductSearchRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(api, api.contains("const ProductSearchExtendedRequestPQON = \"com.acme.api.ProductSearchExtendedRequest\";"));
        assertTrue(api, api.contains("ProductSearchExtendedRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(api, !api.contains("unwrapLean"));

        String apiSource = String.join("\n",
            "package com.acme.api {",
            "    class ServiceResponse {}",
            "    class SearchCriteria { required int limit; required int offset; }",
            "    class LeanSearchResponse extends ServiceResponse {}",
            "    class Description {}",
            "    class LeanSearchRequest extends SearchCriteria return LeanSearchResponse {}",
            "    class PriceListLeanSearchRequest extends LeanSearchRequest {}",
            "    class RefResolverResponse extends ServiceResponse {}",
            "    class RefResolverRequest<REF> return RefResolverResponse {}",
            "    class ProductDTO {}",
            "    class ProductRef {}",
            "    class FullTracking {}",
            "    class ProductResolverRequest extends RefResolverRequest<ProductRef> {}",
            "    class CrudAnyKeyResponse<DATA, TRACKING> extends ServiceResponse {}",
            "    class CrudSurrogateResponse<DATA, TRACKING> extends CrudAnyKeyResponse<DATA, TRACKING> {}",
            "    class CrudSurrogateKeyRequest<REF, DATA, TRACKING> return CrudSurrogateResponse<!DATA, !TRACKING> {}",
            "    class ProductCrudRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> {}",
            "    class ProductCrudViaApiRequest extends CrudSurrogateKeyRequest<ProductRef, ProductDTO, FullTracking> {}",
            "    class CrudStringKeyRequest<DATA, TRACKING> return CrudAnyKeyResponse<!DATA, !TRACKING> {}",
            "    class UserCrudRequest extends CrudStringKeyRequest<ProductDTO, FullTracking> {}",
            "    class CrudCompositeKeyRequest<KEY, DATA, TRACKING> return CrudAnyKeyResponse<!DATA, !TRACKING> {}",
            "    class OrderKey {}",
            "    class OrderCrudRequest extends CrudCompositeKeyRequest<OrderKey, ProductDTO, FullTracking> {}",
            "    class CrudModuleCfgRequest<DATA> extends CrudCompositeKeyRequest<ModuleConfigKey, !DATA, FullTracking> {}",
            "    class ModuleConfigKey {}",
            "    class ProductCrudModuleCfgRequest extends CrudModuleCfgRequest<ProductDTO> {}",
            "    class MassResolverResponse extends ServiceResponse {}",
            "    class MassResolverRequest extends SearchCriteria return MassResolverResponse {}",
            "    class ProductMassResolverRequest extends MassResolverRequest {}",
            "}",
            "");
        Map<String, CharSequence> otherFiles = generateApis(apiSource);
        String priceApi = norm(otherFiles.get(ROOT + "com/acme/api/PriceListApi.ts"));
        assertTrue(priceApi, priceApi.contains("params: Omit<PriceListLeanSearchRequest, '@PQON' | 'offset'> & { offset?: number }"));
        assertTrue(priceApi, priceApi.contains("PriceListLeanSearchRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(priceApi, priceApi.contains("Observable<Description[]>"));
        assertTrue(priceApi, priceApi.contains("map(unwrapLean)"));
        String productApi = norm(otherFiles.get(ROOT + "com/acme/api/ProductApi.ts"));
        assertTrue(productApi, productApi.contains("resolve(params: Omit<ProductResolverRequest, '@PQON'>): Observable<number>"));
        assertTrue(productApi, productApi.contains("map(unwrapResolve)"));
        assertTrue(productApi, productApi.contains("execute(params: Omit<ProductCrudRequest, '@PQON'>): Observable<ProductDTO>"));
        assertTrue(productApi, productApi.contains("import type { ProductRef } from \"./ProductRef\";"));
        assertTrue(productApi, productApi.contains("map(unwrapCrud<ProductDTO>)"));
        assertTrue(productApi, productApi.contains("create(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("\n    create(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("\n        return this.rpc.call<"));
        assertTrue(productApi, !productApi.matches("(?s).*\\n[ \\t]+\\n.*"));
        assertTrue(productApi, productApi.contains("read(key: ProductRef,"));
        assertTrue(productApi, productApi.contains("update(key: ProductRef, data: Partial<ProductDTO>,"));
        assertTrue(productApi, productApi.contains("delete(key: ProductRef,"));
        assertTrue(productApi, productApi.contains("crud: 'C', onlyActive: false, data"));
        assertTrue(productApi, productApi.contains("crud: 'R', onlyActive: false, key"));
        assertTrue(productApi, productApi.contains("crud: 'U', onlyActive: false, key, data"));
        assertTrue(productApi, productApi.contains("crud: 'D', onlyActive: false, key"));
        assertTrue(productApi, productApi.contains("executeViaApi(params: Omit<ProductCrudViaApiRequest, '@PQON'>)"));
        assertTrue(productApi, productApi.contains("createViaApi(data: ProductDTO,"));
        assertTrue(productApi, productApi.contains("readUser(key: string,"));
        assertTrue(productApi, productApi.contains("readOrder(key: OrderKey,"));
        assertTrue(productApi, productApi.contains("readModuleCfg(key: ModuleConfigKey,"));
        assertTrue(productApi, productApi.contains("resolveMany(params: Omit<ProductMassResolverRequest, '@PQON' | 'offset'> & { offset?: number }): Observable<number[]>"));
        assertTrue(productApi, productApi.contains("ProductMassResolverRequestPQON, { ...params, offset: params.offset ?? 0 }"));
        assertTrue(productApi, productApi.contains("map(unwrapResolveMany)"));

        String specialSource = String.join("\n",
            "package com.acme.request {",
            "    class ServiceResponse {}",
            "    class RequestParameters return ServiceResponse {}",
            "    class ReloadAllRequest extends RequestParameters {}",
            "    class DetailResponse extends ServiceResponse { required unicode(20) detail; }",
            "    class DetailRequest extends RequestParameters return DetailResponse {}",
            "}",
            "");
        Map<String, CharSequence> specialFiles = generateApis(specialSource);
        String specialApi = norm(specialFiles.get(ROOT + "com/acme/request/AcmeApi.ts"));
        assertTrue(specialApi, specialApi.contains("reloadAll(params: Omit<ReloadAllRequest, '@PQON'>): Observable<void>"));
        assertTrue(specialApi, specialApi.contains("map(unwrapVoid)"));
        assertTrue(specialApi, specialApi.contains("detail(params: Omit<DetailRequest, '@PQON'>): Observable<Omit<DetailResponse, 'returnCode'>>"));
        assertTrue(specialApi, specialApi.contains("unwrapService<DetailResponse>"));
    }
}
