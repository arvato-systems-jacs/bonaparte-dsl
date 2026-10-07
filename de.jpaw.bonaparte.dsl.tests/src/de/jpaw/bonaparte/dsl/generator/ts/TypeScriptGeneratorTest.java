package de.jpaw.bonaparte.dsl.generator.ts;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Map;

import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.junit.BeforeClass;
import org.junit.Test;

import com.google.inject.Injector;

import de.jpaw.bonaparte.dsl.BonScriptStandaloneSetup;
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
        "    class Base {",
        "        required long objectRef;",
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
        "    }",
        "}",
        "");

    @BeforeClass
    public static void setup() {
        injector = new BonScriptStandaloneSetup().createInjectorAndDoEMFRegistration();
    }

    private Map<String, CharSequence> generate(String source) throws Exception {
        XtextResourceSet rs = injector.getInstance(XtextResourceSet.class);
        XtextResource res = (XtextResource) rs.createResource(URI.createURI("dummy:/test.bon"));
        res.load(new ByteArrayInputStream(source.getBytes(StandardCharsets.UTF_8)), Collections.emptyMap());
        assertTrue("parse errors: " + res.getErrors(), res.getErrors().isEmpty());
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        try {
            injector.getInstance(TypeScriptBonScriptGeneratorMain.class).doGenerate(res, fsa, new GeneratorContext());
        } finally {
            DataTypeExtension.clear();
        }
        return fsa.getTextFiles();
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
        String plain = norm(files.get(ROOT + "com/acme/base/SortOrder.ts"));
        assertTrue(plain, plain.contains("export enum SortOrder {"));
        assertTrue(plain, plain.contains("ASC = \"ASC\","));
        assertTrue(plain, plain.contains("DESC = \"DESC\""));
        // alphanumeric enums use the token as value
        String alpha = norm(files.get(ROOT + "com/acme/base/Mode.ts"));
        assertTrue(alpha, alpha.contains("A = \"a\","));
        assertTrue(alpha, alpha.contains("B = \"b\""));
        assertTrue(norm(files.get(ROOT + "com/acme/base/TimeUnit.ts")).contains("export type TimeUnit = string;"));
    }

    @Test
    public void interfaceWithInheritanceAndImports() throws Exception {
        String base = norm(generate(BON_SOURCE).get(ROOT + "com/acme/base/Base.ts"));
        assertTrue(base, base.contains("export interface Base {"));
        assertTrue(base, base.contains("objectRef: number;"));

        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertTrue(child, child.contains("import type { Base } from \"../base/Base\";"));
        assertTrue(child, child.contains("import type { SortOrder } from \"../base/SortOrder\";"));
        assertTrue(child, child.contains("import type { TimeUnit } from \"../base/TimeUnit\";"));
        assertTrue(child, child.contains("export interface Child<T = unknown> extends Base {"));
    }

    @Test
    public void fieldTypesAndOptionality() throws Exception {
        String child = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertField(child, "name: string;");                     // typedef resolved, required
        assertField(child, "nickname?: string | null;");         // optional scalar
        assertField(child, "active: boolean;");
        assertField(child, "age?: number | null;");
        assertField(child, "created?: string | null;");          // instants are ISO strings
        assertField(child, "order: SortOrder;");
        assertField(child, "unit?: TimeUnit | null;");
        assertField(child, "tags: string[];");                   // required list
        assertField(child, "labels?: Record<string, string>;");  // map
        assertField(child, "other?: Base | null;");
        assertField(child, "payload?: T | null;");               // generics parameter
        assertField(child, "extra?: Record<string, unknown> | null;");
    }

    private static void assertField(String content, String line) {
        assertTrue("expected line '" + line + "' in:\n" + content, content.lines().anyMatch(l -> l.trim().equals(line)));
    }

    @Test
    public void headerMarksFileAsGenerated() throws Exception {
        String content = norm(generate(BON_SOURCE).get(ROOT + "com/acme/auth/Child.ts"));
        assertEquals(TypeScriptBonScriptGeneratorMain.GENERATED_COMMENT, content.lines().findFirst().orElse(""));
    }
}
