-- Dark Cave (Field Spell)
-- If a monster is Normal or Special Summoned, or Set, on the turn player's side of the field: Their opponent
-- Special Summons 1 "Zu Token" (Winged Beast/DARK/Level 2/ATK 300/DEF 100) to their side of the field.
-- It cannot be Tributed for a Tribute Summon.
-- PATTERN: Tokens = a card in cards.txt with "Card type: Normal Token Monster" (here 1900000068),
-- created with Duel.CreateToken(player, ID).
local s,id=GetID()
local ZU_TOKEN=1900000068
function s.initial_effect(c)
	-- Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	-- Mandatory trigger on Normal Summon / Special Summon / Set
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_F)
	e2:SetProperty(EFFECT_FLAG_DELAY)
	e2:SetCode(EVENT_SUMMON_SUCCESS)
	e2:SetRange(LOCATION_FZONE)
	e2:SetCondition(s.tkcon)
	e2:SetTarget(s.tktg)
	e2:SetOperation(s.tkop)
	c:RegisterEffect(e2)
	local e3=e2:Clone() e3:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e3)
	local e4=e2:Clone() e4:SetCode(EVENT_MSET) c:RegisterEffect(e4)
end
s.listed_names={ZU_TOKEN}
-- A monster arrived on the turn player's side (the Token itself goes to the other side, so no loop)
function s.tkcon(e,tp,eg)
	return eg:IsExists(Card.IsControler,1,nil,Duel.GetTurnPlayer())
end
function s.tktg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,0,0)
end
function s.tkop(e,tp,eg,ep,ev,re,r,rp)
	if not e:GetHandler():IsRelateToEffect(e) then return end
	local p=1-Duel.GetTurnPlayer()       -- "their opponent" = the player whose turn it is NOT
	if Duel.GetLocationCount(p,LOCATION_MZONE)<=0
		or not Duel.IsPlayerCanSpecialSummonMonster(p,ZU_TOKEN,0,TYPES_TOKEN,300,100,2,RACE_WINGEDBEAST,ATTRIBUTE_DARK) then return end
	local token=Duel.CreateToken(p,ZU_TOKEN)
	if Duel.SpecialSummonStep(token,0,p,p,false,false,POS_FACEUP) then
		-- Cannot be Tributed for a Tribute Summon
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_UNRELEASABLE_SUM)
		e1:SetValue(1)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		token:RegisterEffect(e1,true)
	end
	Duel.SpecialSummonComplete()
end
