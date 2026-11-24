-- Trading with the worst person ever (Normal Trap)
-- Target 1 Pokemon monster you control, and your opponent targets 1 monster they control; take control of
-- your opponent's targeted monster, then your opponent takes control of your targeted monster.
-- Your monster can be one whose control can't change (like Alakazam): then you get theirs and they get nothing.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_CONTROL)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.mine(c) return c:IsFaceup() and c:IsSetCard(SET_POKEMON) end
function s.theirs(c) return c:IsControlerCanBeChanged() end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return false end
	if chk==0 then return Duel.IsExistingTarget(s.mine,tp,LOCATION_MZONE,0,1,nil)
		and Duel.IsExistingTarget(s.theirs,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local g1=Duel.SelectTarget(tp,s.mine,tp,LOCATION_MZONE,0,1,1,nil)
	-- the OPPONENT picks one of their own monsters
	Duel.Hint(HINT_SELECTMSG,1-tp,HINTMSG_TARGET)
	local g2=Duel.SelectTarget(1-tp,s.theirs,1-tp,LOCATION_MZONE,0,1,1,nil)
	e:SetLabelObject(g1:GetFirst())             -- remember which one is mine
	g1:Merge(g2)
	Duel.SetOperationInfo(0,CATEGORY_CONTROL,g1,#g1,0,0)
end
function s.activate(e,tp)
	local mine=e:GetLabelObject()
	local g=Duel.GetTargetCards(e)
	local theirs=g:Filter(function(c) return c~=mine end,nil):GetFirst()
	-- 1. take theirs (permanently)
	if theirs and theirs:IsControler(1-tp) then Duel.GetControl(theirs,tp) end
	-- 2. give mine (does nothing if mine can't change control)
	if mine and g:IsContains(mine) and mine:IsControler(tp) and mine:IsControlerCanBeChanged() then
		Duel.BreakEffect()
		Duel.GetControl(mine,1-tp)
	end
end
