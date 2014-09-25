/*
 * generated by Xtext
 */
package de.jpaw.bonaparte.jpa.dsl.ui;

import org.eclipse.ui.plugin.AbstractUIPlugin;
import org.eclipse.xtext.documentation.IEObjectDocumentationProvider;
import org.eclipse.xtext.ui.editor.hover.IEObjectHoverProvider;
import org.eclipse.xtext.ui.editor.syntaxcoloring.AbstractAntlrTokenToAttributeIdMapper;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration;

import de.jpaw.bonaparte.dsl.ui.BonAntlrTokenToAttributeIdMapper;
import de.jpaw.bonaparte.dsl.ui.Highlighter;
//import de.jpaw.bonaparte.jpa.dsl.IBDDLPreferenceProvider;
import de.jpaw.bonaparte.jpa.dsl.ui.help.BDDLEObjectDocumentationProvider;
import de.jpaw.bonaparte.jpa.dsl.ui.help.BDDLEObjectHoverProvider;
import de.jpaw.bonaparte.jpa.dsl.ui.scoping.BDDLGlobalScopeProvider;

/**
 * Use this class to register components to be used within the IDE.
 */
public class BDDLUiModule extends de.jpaw.bonaparte.jpa.dsl.ui.AbstractBDDLUiModule {
    public BDDLUiModule(AbstractUIPlugin plugin) {
        super(plugin);
    }

//  public Class<? extends IBDDLPreferenceProvider> bindPreferenceProvider() {
//      System.out.println("BDDL config bound");
//      return BDDLConfiguration.class;
//  }
    public Class<? extends org.eclipse.xtext.ui.editor.preferences.LanguageRootPreferencePage> bindLanguageRootPreferencePage() {
        return BDDLConfiguration.class;
    }
    public Class<? extends IHighlightingConfiguration> bindIHighlightingConfiguration() {
        return Highlighter.class;
    }

    /* online help possibly causing issues, commenting out...
    public Class<? extends IEObjectHoverProvider> bindIEObjectHoverProvider() {
        return BDDLEObjectHoverProvider.class;
    }
 
    public Class<? extends IEObjectDocumentationProvider> bindIEObjectDocumentationProviderr() {
        return BDDLEObjectDocumentationProvider.class;
    } */
    
/*  // contributed by org.eclipse.xtext.generator.parser.antlr.XtextAntlrGeneratorFragment
    public Class<? extends org.eclipse.jface.text.rules.ITokenScanner> bindITokenScanner() {
        return AbstractTokenScanner.class;
    } */

    public Class<? extends AbstractAntlrTokenToAttributeIdMapper> bindAbstractAntlrTokenToAttributeIdMapper() {
        return BonAntlrTokenToAttributeIdMapper.class ;
    }
    
    public Class<? extends org.eclipse.xtext.scoping.IGlobalScopeProvider> bindIGlobalScopeProvider() {
        return BDDLGlobalScopeProvider.class;
    }
}