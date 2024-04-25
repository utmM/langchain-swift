//
//  File.swift
//  
//
//  Created by 顾艳华 on 2023/11/3.
//

import Foundation
public class BaseConversationalRetrievalChain: DefaultChain {

    static let _template = """
    以下の会話とそれに続く質問を、独立した質問に書き換えてください。

    会話履歴:
    {chat_history}
    続きの質問: {question}
    独立した質問:
    """
    static let CONDENSE_QUESTION_PROMPT = PromptTemplate(input_variables: ["chat_history", "question"], partial_variable: [:], template: _template)

    let combineChain: BaseCombineDocumentsChain
    let condense_question_chain: LLMChain
    
    init(llm: LLM) {
        self.combineChain = StuffDocumentsChain(llm: llm)
        self.condense_question_chain = LLMChain(llm: llm, prompt: BaseConversationalRetrievalChain.CONDENSE_QUESTION_PROMPT)
        super.init(outputKey: "", inputKey: "")
    }
    public func get_docs(question: String) async -> String {
        ""
    }
    
    public func predict(args: [String: String] ) async -> (String, String?)? {
        let new_question = await self.condense_question_chain.predict(args: args)
        if let new_question = new_question {
            let output = await combineChain.predict(args: ["docs": await self.get_docs(question: new_question), "question": new_question])
            if let text = output {
                let pattern = "Helpful\\s*Answer\\s*:[\\s]*(.*)[\\s]*Dependent\\s*text\\s*:[\\s]*(.*)"
                let regex = try! NSRegularExpression(pattern: pattern)
                
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                    
                    let firstCaptureGroup = Range(match.range(at: 1), in: text).map { String(text[$0]) }
                    //            print(firstCaptureGroup!)
                    
                    
                    let secondCaptureGroup = Range(match.range(at: 2), in: text).map { String(text[$0]) }
                    return (firstCaptureGroup!, secondCaptureGroup!)
                } else {
                    return (text.replacingOccurrences(of: "Helpful Answer:", with: ""), nil)
                }
            }
        }
        return nil
    }
    
    
    public static func get_chat_history(chat_history: [(String, String)]) -> String {
        var buffer = ""
        for dialogue_turn in chat_history {
            let human = "Human: " + dialogue_turn.0
            let ai = "Assistant: " + dialogue_turn.1
            buffer += "\n\(human)\n\(ai)"
        }
        return buffer
//        chat_history.joined(separator: "\n")
    }
}
